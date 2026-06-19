import Foundation
import SwiftData

// MARK: - Catalog entities
// Artist / Album / Track are first-class records. They may originate from Spotify
// (then `spotifyID` is set) or be created by hand for items not on Spotify.

@Model
final class Artist {
    @Attribute(.unique) var id: String        // Spotify ID, or a local UUID string
    var name: String
    var spotifyID: String?
    var imageURL: String?
    var genres: [String]

    init(id: String = UUID().uuidString,
         name: String,
         spotifyID: String? = nil,
         imageURL: String? = nil,
         genres: [String] = []) {
        self.id = id
        self.name = name
        self.spotifyID = spotifyID
        self.imageURL = imageURL
        self.genres = genres
    }
}

@Model
final class Album {
    @Attribute(.unique) var id: String        // Spotify ID, or a local UUID string
    var title: String
    var artistName: String
    var artistID: String?
    var spotifyID: String?
    var coverURL: String?
    var releaseYear: Int?
    var totalTracks: Int?
    var isManual: Bool                         // true when hand-entered (e.g. a record not on Spotify)
    var addedAt: Date

    /// Physical copies the user owns. Owning ≥1 copy is what makes an album "vinyl".
    @Relationship(deleteRule: .cascade, inverse: \VinylCopy.album)
    var vinylCopies: [VinylCopy] = []

    init(id: String = UUID().uuidString,
         title: String,
         artistName: String,
         artistID: String? = nil,
         spotifyID: String? = nil,
         coverURL: String? = nil,
         releaseYear: Int? = nil,
         totalTracks: Int? = nil,
         isManual: Bool = false,
         addedAt: Date = .now) {
        self.id = id
        self.title = title
        self.artistName = artistName
        self.artistID = artistID
        self.spotifyID = spotifyID
        self.coverURL = coverURL
        self.releaseYear = releaseYear
        self.totalTracks = totalTracks
        self.isManual = isManual
        self.addedAt = addedAt
    }

    var ownedOnVinyl: Bool { !vinylCopies.isEmpty }
}

@Model
final class Track {
    @Attribute(.unique) var id: String        // Spotify ID, or a local UUID string
    var title: String
    var artistName: String
    var albumTitle: String?
    var albumID: String?
    var spotifyID: String?
    var coverURL: String?
    var durationMs: Int?
    var trackNumber: Int?
    var addedAt: Date

    init(id: String = UUID().uuidString,
         title: String,
         artistName: String,
         albumTitle: String? = nil,
         albumID: String? = nil,
         spotifyID: String? = nil,
         coverURL: String? = nil,
         durationMs: Int? = nil,
         trackNumber: Int? = nil,
         addedAt: Date = .now) {
        self.id = id
        self.title = title
        self.artistName = artistName
        self.albumTitle = albumTitle
        self.albumID = albumID
        self.spotifyID = spotifyID
        self.coverURL = coverURL
        self.durationMs = durationMs
        self.trackNumber = trackNumber
        self.addedAt = addedAt
    }
}

// MARK: - Vinyl copy
// A physical record attached to an Album. An album with copies shows up in the Vinyl tab,
// but is otherwise an ordinary album everywhere else in the app.

@Model
final class VinylCopy {
    var id: String
    var album: Album?
    var label: String
    var catalogNumber: String
    var pressingYear: Int?
    var color: String                          // e.g. "Black", "Translucent Red", "Picture Disc"
    var conditionRaw: String
    var notes: String
    var addedAt: Date

    init(id: String = UUID().uuidString,
         album: Album? = nil,
         label: String = "",
         catalogNumber: String = "",
         pressingYear: Int? = nil,
         color: String = "Black",
         condition: VinylCondition = .nearMint,
         notes: String = "",
         addedAt: Date = .now) {
        self.id = id
        self.album = album
        self.label = label
        self.catalogNumber = catalogNumber
        self.pressingYear = pressingYear
        self.color = color
        self.conditionRaw = condition.rawValue
        self.notes = notes
        self.addedAt = addedAt
    }

    var condition: VinylCondition {
        get { VinylCondition(rawValue: conditionRaw) ?? .nearMint }
        set { conditionRaw = newValue.rawValue }
    }
}
