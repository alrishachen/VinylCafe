import Foundation

/// Whether a rating / review / list entry points at an album or a single track.
enum SubjectType: String, Codable, CaseIterable, Identifiable {
    case album
    case track
    var id: String { rawValue }
    var label: String { self == .album ? "Album" : "Song" }
    var systemImage: String { self == .album ? "square.stack" : "music.note" }
}

/// The buckets a saved item can live in. `custom` lists carry a user-supplied name.
enum ListKind: String, Codable, CaseIterable, Identifiable {
    case wantToListen
    case good
    case custom

    var id: String { rawValue }
    var title: String {
        switch self {
        case .wantToListen: return "Want to Listen"
        case .good: return "Good Stuff"
        case .custom: return "Custom"
        }
    }
    var systemImage: String {
        switch self {
        case .wantToListen: return "clock.badge.checkmark"
        case .good: return "hand.thumbsup"
        case .custom: return "star"
        }
    }
}

/// Where a play record came from, so analytics can show coverage.
enum PlaySource: String, Codable, CaseIterable {
    case recentlyPlayed   // pulled from Spotify "recently played" sync
    case spotifyImport    // parsed from a Spotify GDPR data export
    case manual           // logged by hand
}

/// Media condition grades used by record collectors (Goldmine standard).
enum VinylCondition: String, Codable, CaseIterable, Identifiable {
    case mint = "Mint"
    case nearMint = "Near Mint"
    case veryGoodPlus = "Very Good Plus"
    case veryGood = "Very Good"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"

    var id: String { rawValue }
    var abbreviation: String {
        switch self {
        case .mint: return "M"
        case .nearMint: return "NM"
        case .veryGoodPlus: return "VG+"
        case .veryGood: return "VG"
        case .good: return "G"
        case .fair: return "F"
        case .poor: return "P"
        }
    }
}

/// Ways a list can be ordered in the UI.
enum ListSort: String, CaseIterable, Identifiable {
    case manual = "Custom Order"
    case dateAdded = "Date Added"
    case title = "Title"
    case artist = "Artist"
    case rating = "Rating"
    var id: String { rawValue }
}
