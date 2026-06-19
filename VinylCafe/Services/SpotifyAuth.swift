import Foundation
import CryptoKit
import AuthenticationServices
import UIKit

/// OAuth tokens returned by Spotify. Persisted in the Keychain between launches.
struct SpotifyTokens: Codable {
    var accessToken: String
    var refreshToken: String?
    var expiresAt: Date

    var isExpired: Bool { Date() >= expiresAt.addingTimeInterval(-60) }
}

enum SpotifyAuthError: LocalizedError {
    case notConfigured
    case userCancelled
    case badCallback
    case tokenExchangeFailed(String)
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Add your Spotify Client ID in Settings first."
        case .userCancelled: return "Sign-in was cancelled."
        case .badCallback: return "Spotify returned an unexpected response."
        case .tokenExchangeFailed(let m): return "Couldn't complete sign-in: \(m)"
        case .notAuthenticated: return "You're not signed in to Spotify."
        }
    }
}

/// Drives Authorization Code + PKCE sign-in via ASWebAuthenticationSession and
/// keeps the access token fresh. The correct flow for a native app with no secret.
@MainActor
final class SpotifyAuth: NSObject, ASWebAuthenticationPresentationContextProviding {
    private let tokenKey = "spotify.tokens"
    private let tokenURL = URL(string: "https://accounts.spotify.com/api/token")!
    private let authBase = "https://accounts.spotify.com/authorize"

    private var session: ASWebAuthenticationSession?

    var tokens: SpotifyTokens? {
        guard let data = Keychain.get(tokenKey) else { return nil }
        return try? JSONDecoder().decode(SpotifyTokens.self, from: data)
    }

    var isAuthenticated: Bool { tokens != nil }

    private func store(_ tokens: SpotifyTokens) {
        if let data = try? JSONEncoder().encode(tokens) {
            Keychain.set(data, for: tokenKey)
        }
    }

    func signOut() {
        Keychain.delete(tokenKey)
    }

    // MARK: - Sign in

    func signIn() async throws {
        guard SpotifyConfig.isConfigured else { throw SpotifyAuthError.notConfigured }

        let verifier = Self.makeCodeVerifier()
        let challenge = Self.codeChallenge(for: verifier)
        let state = UUID().uuidString

        var components = URLComponents(string: authBase)!
        components.queryItems = [
            .init(name: "client_id", value: SpotifyConfig.clientID),
            .init(name: "response_type", value: "code"),
            .init(name: "redirect_uri", value: SpotifyConfig.redirectURI),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "code_challenge", value: challenge),
            .init(name: "scope", value: SpotifyConfig.scopeString),
            .init(name: "state", value: state),
        ]
        guard let authURL = components.url,
              let scheme = URL(string: SpotifyConfig.redirectURI)?.scheme else {
            throw SpotifyAuthError.badCallback
        }

        let callback = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: scheme) { url, error in
                if let url {
                    cont.resume(returning: url)
                } else if let error = error as? ASWebAuthenticationSessionError,
                          error.code == .canceledLogin {
                    cont.resume(throwing: SpotifyAuthError.userCancelled)
                } else {
                    cont.resume(throwing: error ?? SpotifyAuthError.badCallback)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.session = session
            session.start()
        }

        guard let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems,
              let code = items.first(where: { $0.name == "code" })?.value,
              items.first(where: { $0.name == "state" })?.value == state else {
            throw SpotifyAuthError.badCallback
        }

        try await exchangeCode(code, verifier: verifier)
    }

    private func exchangeCode(_ code: String, verifier: String) async throws {
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formBody([
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": SpotifyConfig.redirectURI,
            "client_id": SpotifyConfig.clientID,
            "code_verifier": verifier,
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response, data: data)
        store(try Self.decodeTokens(data, existingRefresh: nil))
    }

    // MARK: - Token access / refresh

    /// Returns a valid access token, refreshing transparently when needed.
    func validAccessToken() async throws -> String {
        guard let current = tokens else { throw SpotifyAuthError.notAuthenticated }
        if !current.isExpired { return current.accessToken }
        guard let refresh = current.refreshToken else { throw SpotifyAuthError.notAuthenticated }

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formBody([
            "grant_type": "refresh_token",
            "refresh_token": refresh,
            "client_id": SpotifyConfig.clientID,
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response, data: data)
        let refreshed = try Self.decodeTokens(data, existingRefresh: refresh)
        store(refreshed)
        return refreshed.accessToken
    }

    // MARK: - Presentation anchor

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        return scene?.keyWindow ?? ASPresentationAnchor()
    }

    // MARK: - Helpers

    private struct TokenResponse: Decodable {
        let access_token: String
        let refresh_token: String?
        let expires_in: Int
    }

    private static func decodeTokens(_ data: Data, existingRefresh: String?) throws -> SpotifyTokens {
        let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
        return SpotifyTokens(
            accessToken: decoded.access_token,
            refreshToken: decoded.refresh_token ?? existingRefresh,
            expiresAt: Date().addingTimeInterval(TimeInterval(decoded.expires_in))
        )
    }

    private static func validate(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw SpotifyAuthError.tokenExchangeFailed(body)
        }
    }

    private static func formBody(_ params: [String: String]) -> Data {
        var comps = URLComponents()
        comps.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        return comps.percentEncodedQuery?.data(using: .utf8) ?? Data()
    }

    // MARK: PKCE

    static func makeCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64URL(Data(bytes))
    }

    static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return base64URL(Data(digest))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
