import Foundation
import SwiftData

/// Pulls Spotify "recently played" and appends any new listens to the local history,
/// deduping so repeated syncs don't double-count. History grows forward from here.
@MainActor
enum SyncService {
    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static func parseDate(_ string: String) -> Date? {
        iso.date(from: string) ?? ISO8601DateFormatter().date(from: string)
    }

    @discardableResult
    static func sync(api: SpotifyAPIClient, context: ModelContext) async throws -> Int {
        let items = try await api.recentlyPlayed()

        // Build a set of existing dedupe keys so we skip plays we already have.
        let existing = (try? context.fetch(FetchDescriptor<PlayRecord>())) ?? []
        var seen = Set(existing.map(\.dedupeKey))

        var added = 0
        for item in items {
            guard let playedAt = parseDate(item.played_at) else { continue }
            let record = PlayRecord(
                trackID: item.track.id,
                trackName: item.track.name,
                artistName: item.track.primaryArtist,
                albumName: item.track.album?.name,
                playedAt: playedAt,
                msPlayed: item.track.duration_ms ?? 0,
                source: .recentlyPlayed
            )
            if seen.contains(record.dedupeKey) { continue }
            seen.insert(record.dedupeKey)
            context.insert(record)
            added += 1
        }
        if added > 0 { try? context.save() }
        return added
    }
}
