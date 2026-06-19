import Foundation

/// Holds the bits of Spotify setup the user supplies. The Client ID comes from the
/// free developer-app registration (see SETUP.md) and is stored in UserDefaults so it
/// survives launches. No client secret is needed — we use Authorization Code + PKCE.
enum SpotifyConfig {
    private static let clientIDKey = "spotify.clientID"

    /// Custom URL scheme registered in Info.plist (CFBundleURLTypes). Must match the
    /// Redirect URI added to the Spotify dashboard exactly.
    static let redirectURI = "vinylcafe://callback"

    /// Read access only — everything this app needs.
    static let scopes = [
        "user-read-private",
        "user-read-email",
        "user-read-recently-played",
        "user-top-read",
        "user-library-read",
    ]

    static var clientID: String {
        get { UserDefaults.standard.string(forKey: clientIDKey) ?? "" }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines),
                                        forKey: clientIDKey) }
    }

    static var isConfigured: Bool { !clientID.isEmpty }

    static var scopeString: String { scopes.joined(separator: " ") }
}
