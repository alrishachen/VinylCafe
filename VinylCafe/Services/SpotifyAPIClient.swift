import Foundation

// MARK: - DTOs (only the fields we use)

struct SpotifyUser: Decodable {
    let display_name: String?
    let id: String
    let images: [SpotifyImage]?
}

struct SpotifyImage: Decodable { let url: String }

struct SpotifyArtistRef: Decodable {
    let id: String?
    let name: String
}

struct SpotifyAlbumRef: Decodable {
    let id: String?
    let name: String
    let images: [SpotifyImage]?
    let release_date: String?
    let total_tracks: Int?
}

struct SpotifyTrack: Decodable {
    let id: String?
    let name: String
    let artists: [SpotifyArtistRef]
    let album: SpotifyAlbumRef?
    let duration_ms: Int?
    let track_number: Int?

    var primaryArtist: String { artists.first?.name ?? "Unknown Artist" }
    var coverURL: String? { album?.images?.first?.url }
}

struct SpotifyArtist: Decodable {
    let id: String
    let name: String
    let images: [SpotifyImage]?
    let genres: [String]?
    var imageURL: String? { images?.first?.url }
}

struct RecentlyPlayedItem: Decodable {
    let track: SpotifyTrack
    let played_at: String
}

private struct PagingTracks: Decodable { let items: [SpotifyTrack] }
private struct PagingArtists: Decodable { let items: [SpotifyArtist] }
private struct RecentlyPlayedResponse: Decodable { let items: [RecentlyPlayedItem] }
private struct SearchResponse: Decodable {
    struct Albums: Decodable { let items: [SpotifyAlbumFull] }
    let albums: Albums?
}
struct SpotifyAlbumFull: Decodable {
    let id: String
    let name: String
    let artists: [SpotifyArtistRef]
    let images: [SpotifyImage]?
    let release_date: String?
    let total_tracks: Int?
    var primaryArtist: String { artists.first?.name ?? "Unknown Artist" }
    var coverURL: String? { images?.first?.url }
    var year: Int? { release_date.flatMap { Int($0.prefix(4)) } }
}

enum SpotifyTimeRange: String, CaseIterable, Identifiable {
    case shortTerm = "short_term"     // ~4 weeks
    case mediumTerm = "medium_term"   // ~6 months
    case longTerm = "long_term"       // ~1 year
    var id: String { rawValue }
    var label: String {
        switch self {
        case .shortTerm: return "4 weeks"
        case .mediumTerm: return "6 months"
        case .longTerm: return "1 year"
        }
    }
}

enum SpotifyAPIError: LocalizedError {
    case http(Int, String)
    var errorDescription: String? {
        switch self {
        case .http(let code, let body):
            if code == 403 { return "Spotify denied this request (403). New apps can't use deprecated endpoints." }
            if code == 401 { return "Spotify session expired — try reconnecting." }
            return "Spotify error \(code): \(body)"
        }
    }
}

/// Thin async wrapper over the Spotify Web API endpoints this app relies on.
@MainActor
final class SpotifyAPIClient {
    private let base = URL(string: "https://api.spotify.com/v1")!
    private let auth: SpotifyAuth

    init(auth: SpotifyAuth) { self.auth = auth }

    // MARK: Endpoints

    func currentUser() async throws -> SpotifyUser {
        try await get("/me")
    }

    /// Last 50 plays (rolling window — Spotify exposes no deeper history via API).
    func recentlyPlayed(limit: Int = 50) async throws -> [RecentlyPlayedItem] {
        let response: RecentlyPlayedResponse = try await get("/me/player/recently-played?limit=\(limit)")
        return response.items
    }

    func topTracks(_ range: SpotifyTimeRange, limit: Int = 30) async throws -> [SpotifyTrack] {
        let response: PagingTracks = try await get("/me/top/tracks?time_range=\(range.rawValue)&limit=\(limit)")
        return response.items
    }

    func topArtists(_ range: SpotifyTimeRange, limit: Int = 30) async throws -> [SpotifyArtist] {
        let response: PagingArtists = try await get("/me/top/artists?time_range=\(range.rawValue)&limit=\(limit)")
        return response.items
    }

    func searchAlbums(_ query: String, limit: Int = 20) async throws -> [SpotifyAlbumFull] {
        let q = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let response: SearchResponse = try await get("/search?type=album&limit=\(limit)&q=\(q)")
        return response.albums?.items ?? []
    }

    // MARK: Core request

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let token = try await auth.validAccessToken()
        let url = URL(string: base.absoluteString + path)!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw SpotifyAPIError.http(http.statusCode, body)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
