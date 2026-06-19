import Foundation
import SwiftData

/// Parses a Spotify data export and turns it into play history. This is the only way to
/// get years of complete listening data, since the API exposes just the last 50 plays.
///
/// Supports both export shapes Spotify has shipped:
///  • "Extended streaming history": keys `ts`, `ms_played`, `master_metadata_track_name`, …
///  • Older "StreamingHistory*.json": keys `endTime`, `msPlayed`, `trackName`, `artistName`
@MainActor
enum ImportService {

    struct ImportResult {
        var added = 0
        var skipped = 0
        var filesParsed = 0
    }

    private struct ExtendedEntry: Decodable {
        let ts: String
        let ms_played: Int?
        let master_metadata_track_name: String?
        let master_metadata_album_artist_name: String?
        let master_metadata_album_album_name: String?
        let spotify_track_uri: String?
    }

    private struct LegacyEntry: Decodable {
        let endTime: String
        let artistName: String?
        let trackName: String?
        let msPlayed: Int?
    }

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f
    }()
    private static let legacyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func importFiles(_ urls: [URL], context: ModelContext) throws -> ImportResult {
        var result = ImportResult()

        let existing = (try? context.fetch(FetchDescriptor<PlayRecord>())) ?? []
        var seen = Set(existing.map(\.dedupeKey))

        for url in urls {
            let needsStop = url.startAccessingSecurityScopedResource()
            defer { if needsStop { url.stopAccessingSecurityScopedResource() } }

            guard let data = try? Data(contentsOf: url) else { continue }
            let records = parse(data)
            guard !records.isEmpty else { continue }
            result.filesParsed += 1

            for record in records {
                if seen.contains(record.dedupeKey) { result.skipped += 1; continue }
                seen.insert(record.dedupeKey)
                context.insert(record)
                result.added += 1
            }
        }
        if result.added > 0 { try? context.save() }
        return result
    }

    private static func parse(_ data: Data) -> [PlayRecord] {
        let decoder = JSONDecoder()
        if let extended = try? decoder.decode([ExtendedEntry].self, from: data) {
            return extended.compactMap { entry in
                guard let name = entry.master_metadata_track_name,
                      let date = isoFractional.date(from: entry.ts) ?? ISO8601DateFormatter().date(from: entry.ts)
                else { return nil }
                let ms = entry.ms_played ?? 0
                guard ms >= 30_000 else { return nil }   // ignore skips under 30s
                return PlayRecord(
                    trackID: entry.spotify_track_uri?.replacingOccurrences(of: "spotify:track:", with: ""),
                    trackName: name,
                    artistName: entry.master_metadata_album_artist_name ?? "Unknown Artist",
                    albumName: entry.master_metadata_album_album_name,
                    playedAt: date,
                    msPlayed: ms,
                    source: .spotifyImport
                )
            }
        }
        if let legacy = try? decoder.decode([LegacyEntry].self, from: data) {
            return legacy.compactMap { entry in
                guard let name = entry.trackName,
                      let date = legacyFormatter.date(from: entry.endTime) else { return nil }
                let ms = entry.msPlayed ?? 0
                guard ms >= 30_000 else { return nil }
                return PlayRecord(
                    trackName: name,
                    artistName: entry.artistName ?? "Unknown Artist",
                    playedAt: date,
                    msPlayed: ms,
                    source: .spotifyImport
                )
            }
        }
        return []
    }
}
