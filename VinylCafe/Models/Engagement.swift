import Foundation
import SwiftData

// MARK: - Play history
// The backbone of analytics. One row per listen, accumulated from Spotify "recently played"
// syncs and/or a Spotify data-export import.

@Model
final class PlayRecord {
    var id: String
    var trackID: String?
    var trackName: String
    var artistName: String
    var albumName: String?
    var playedAt: Date
    var msPlayed: Int
    var sourceRaw: String

    init(id: String = UUID().uuidString,
         trackID: String? = nil,
         trackName: String,
         artistName: String,
         albumName: String? = nil,
         playedAt: Date,
         msPlayed: Int = 0,
         source: PlaySource = .recentlyPlayed) {
        self.id = id
        self.trackID = trackID
        self.trackName = trackName
        self.artistName = artistName
        self.albumName = albumName
        self.playedAt = playedAt
        self.msPlayed = msPlayed
        self.sourceRaw = source.rawValue
    }

    var source: PlaySource {
        get { PlaySource(rawValue: sourceRaw) ?? .recentlyPlayed }
        set { sourceRaw = newValue.rawValue }
    }

    /// Stable key used to dedupe sync results (same track at the same minute = same play).
    var dedupeKey: String {
        let minute = Int(playedAt.timeIntervalSince1970 / 60)
        return "\(trackID ?? trackName)|\(minute)"
    }
}

// MARK: - Ratings

@Model
final class Rating {
    var id: String
    var subjectTypeRaw: String
    var subjectID: String
    var subjectName: String
    var artistName: String
    var coverURL: String?
    var stars: Double          // 0.5 ... 5.0 in half steps
    var createdAt: Date
    var updatedAt: Date

    init(id: String = UUID().uuidString,
         subjectType: SubjectType,
         subjectID: String,
         subjectName: String,
         artistName: String,
         coverURL: String? = nil,
         stars: Double,
         createdAt: Date = .now,
         updatedAt: Date = .now) {
        self.id = id
        self.subjectTypeRaw = subjectType.rawValue
        self.subjectID = subjectID
        self.subjectName = subjectName
        self.artistName = artistName
        self.coverURL = coverURL
        self.stars = stars
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var subjectType: SubjectType {
        get { SubjectType(rawValue: subjectTypeRaw) ?? .album }
        set { subjectTypeRaw = newValue.rawValue }
    }
}

// MARK: - Reviews

@Model
final class Review {
    var id: String
    var subjectTypeRaw: String
    var subjectID: String
    var subjectName: String
    var artistName: String
    var coverURL: String?
    var text: String
    var stars: Double?         // optional snapshot of the rating at write time
    var createdAt: Date
    var updatedAt: Date

    init(id: String = UUID().uuidString,
         subjectType: SubjectType,
         subjectID: String,
         subjectName: String,
         artistName: String,
         coverURL: String? = nil,
         text: String,
         stars: Double? = nil,
         createdAt: Date = .now,
         updatedAt: Date = .now) {
        self.id = id
        self.subjectTypeRaw = subjectType.rawValue
        self.subjectID = subjectID
        self.subjectName = subjectName
        self.artistName = artistName
        self.coverURL = coverURL
        self.text = text
        self.stars = stars
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var subjectType: SubjectType {
        get { SubjectType(rawValue: subjectTypeRaw) ?? .album }
        set { subjectTypeRaw = newValue.rawValue }
    }
}

// MARK: - List entries

@Model
final class ListEntry {
    var id: String
    var kindRaw: String
    var customListName: String?    // set when kind == .custom
    var subjectTypeRaw: String
    var subjectID: String
    var subjectName: String
    var artistName: String
    var coverURL: String?
    var note: String
    var sortIndex: Int
    var addedAt: Date

    init(id: String = UUID().uuidString,
         kind: ListKind,
         customListName: String? = nil,
         subjectType: SubjectType,
         subjectID: String,
         subjectName: String,
         artistName: String,
         coverURL: String? = nil,
         note: String = "",
         sortIndex: Int = 0,
         addedAt: Date = .now) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.customListName = customListName
        self.subjectTypeRaw = subjectType.rawValue
        self.subjectID = subjectID
        self.subjectName = subjectName
        self.artistName = artistName
        self.coverURL = coverURL
        self.note = note
        self.sortIndex = sortIndex
        self.addedAt = addedAt
    }

    var kind: ListKind {
        get { ListKind(rawValue: kindRaw) ?? .wantToListen }
        set { kindRaw = newValue.rawValue }
    }
    var subjectType: SubjectType {
        get { SubjectType(rawValue: subjectTypeRaw) ?? .album }
        set { subjectTypeRaw = newValue.rawValue }
    }
    /// Display name for the bucket this entry belongs to.
    var listDisplayName: String {
        kind == .custom ? (customListName ?? "Custom") : kind.title
    }
}
