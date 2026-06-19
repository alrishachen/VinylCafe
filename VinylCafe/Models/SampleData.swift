import Foundation
import SwiftData

/// Seeds a fresh store with a little content so every tab has something to show
/// before the user connects Spotify. Runs once, only when the store is empty.
enum SampleData {

    struct SeedAlbum {
        let title: String
        let artist: String
        let year: Int
        let onVinyl: Bool
        let label: String
        let catalog: String
    }

    static let albums: [SeedAlbum] = [
        .init(title: "In Rainbows", artist: "Radiohead", year: 2007, onVinyl: true,  label: "XL Recordings", catalog: "XLLP324"),
        .init(title: "Rumours", artist: "Fleetwood Mac", year: 1977, onVinyl: true,  label: "Warner Bros.",  catalog: "BSK 3010"),
        .init(title: "Currents", artist: "Tame Impala", year: 2015, onVinyl: true,  label: "Modular",       catalog: "MODVL192"),
        .init(title: "Blonde", artist: "Frank Ocean", year: 2016, onVinyl: false, label: "",              catalog: ""),
        .init(title: "SOS", artist: "SZA", year: 2022, onVinyl: false, label: "",              catalog: ""),
        .init(title: "For Emma, Forever Ago", artist: "Bon Iver", year: 2007, onVinyl: true, label: "Jagjaguwar", catalog: "JAG115"),
    ]

    static func seedIfNeeded(_ context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<Album>())) ?? 0
        guard existing == 0 else { return }
        seed(context)
    }

    static func seed(_ context: ModelContext) {
        var created: [String: Album] = [:]

        for seed in albums {
            let album = Album(title: seed.title,
                              artistName: seed.artist,
                              releaseYear: seed.year,
                              isManual: false)
            context.insert(album)
            created[seed.title] = album

            if seed.onVinyl {
                let copy = VinylCopy(album: album,
                                     label: seed.label,
                                     catalogNumber: seed.catalog,
                                     pressingYear: seed.year,
                                     color: "Black",
                                     condition: .nearMint)
                context.insert(copy)
            }
        }

        // A few ratings.
        rate(created["In Rainbows"], 5.0, context)
        rate(created["Rumours"], 4.5, context)
        rate(created["Blonde"], 5.0, context)
        rate(created["Currents"], 4.0, context)

        // A couple of reviews.
        if let a = created["In Rainbows"] {
            let r = Review(subjectType: .album, subjectID: a.id, subjectName: a.title,
                           artistName: a.artistName,
                           text: "Still the high-water mark. \"Reckoner\" alone earns the five.",
                           stars: 5.0)
            context.insert(r)
        }
        if let a = created["Blonde"] {
            let r = Review(subjectType: .album, subjectID: a.id, subjectName: a.title,
                           artistName: a.artistName,
                           text: "A grower that became a permanent resident. Best late-night record I own.",
                           stars: 5.0)
            context.insert(r)
        }

        // Lists.
        if let a = created["SOS"] {
            context.insert(ListEntry(kind: .wantToListen, subjectType: .album, subjectID: a.id,
                                     subjectName: a.title, artistName: a.artistName, sortIndex: 0))
        }
        if let a = created["For Emma, Forever Ago"] {
            context.insert(ListEntry(kind: .good, subjectType: .album, subjectID: a.id,
                                     subjectName: a.title, artistName: a.artistName, sortIndex: 0))
        }
        if let a = created["Currents"] {
            context.insert(ListEntry(kind: .good, subjectType: .album, subjectID: a.id,
                                     subjectName: a.title, artistName: a.artistName, sortIndex: 1))
        }

        seedPlays(context)
        try? context.save()
    }

    private static func rate(_ album: Album?, _ stars: Double, _ context: ModelContext) {
        guard let album else { return }
        context.insert(Rating(subjectType: .album, subjectID: album.id,
                              subjectName: album.title, artistName: album.artistName, stars: stars))
    }

    /// Generates ~4 months of synthetic listening so the Dashboard has charts on day one.
    private static func seedPlays(_ context: ModelContext) {
        let catalog: [(track: String, artist: String, album: String)] = [
            ("Weird Fishes/Arpeggi", "Radiohead", "In Rainbows"),
            ("Nude", "Radiohead", "In Rainbows"),
            ("Reckoner", "Radiohead", "In Rainbows"),
            ("The Chain", "Fleetwood Mac", "Rumours"),
            ("Dreams", "Fleetwood Mac", "Rumours"),
            ("Let It Happen", "Tame Impala", "Currents"),
            ("The Less I Know the Better", "Tame Impala", "Currents"),
            ("Nights", "Frank Ocean", "Blonde"),
            ("Self Control", "Frank Ocean", "Blonde"),
            ("Ivy", "Frank Ocean", "Blonde"),
            ("Kill Bill", "SZA", "SOS"),
            ("Snooze", "SZA", "SOS"),
            ("Skinny Love", "Bon Iver", "For Emma, Forever Ago"),
            ("re: Stacks", "Bon Iver", "For Emma, Forever Ago"),
        ]

        let calendar = Calendar.current
        let now = Date()
        // Weight toward a handful of favorites so "top artists" looks real.
        let weights = [6, 4, 3, 5, 4, 5, 4, 6, 5, 4, 7, 5, 3, 2]

        var plays: [PlayRecord] = []
        for dayOffset in 0..<120 {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let listensToday = Int.random(in: 0...9)
            for _ in 0..<listensToday {
                // Weighted pick.
                let total = weights.reduce(0, +)
                var pick = Int.random(in: 0..<total)
                var idx = 0
                for (i, w) in weights.enumerated() {
                    if pick < w { idx = i; break }
                    pick -= w
                }
                let item = catalog[idx]
                let hour = Int.random(in: 7...23)
                let minute = Int.random(in: 0...59)
                var comps = calendar.dateComponents([.year, .month, .day], from: day)
                comps.hour = hour
                comps.minute = minute
                let playedAt = calendar.date(from: comps) ?? day
                plays.append(PlayRecord(trackName: item.track,
                                        artistName: item.artist,
                                        albumName: item.album,
                                        playedAt: playedAt,
                                        msPlayed: Int.random(in: 90_000...260_000),
                                        source: .spotifyImport))
            }
        }
        for p in plays { context.insert(p) }
    }
}
