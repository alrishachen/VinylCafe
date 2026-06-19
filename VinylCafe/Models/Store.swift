import Foundation
import SwiftData

/// Thin helpers over `ModelContext` for the read/write patterns the UI repeats:
/// looking up a subject's rating/review and toggling list membership. Keeping these
/// in one place avoids duplicating fetch logic across the feature views.
struct LibraryActions {
    let context: ModelContext

    // MARK: Ratings

    func rating(forSubjectID id: String) -> Rating? {
        var d = FetchDescriptor<Rating>(predicate: #Predicate { $0.subjectID == id })
        d.fetchLimit = 1
        return (try? context.fetch(d))?.first
    }

    /// Sets (or clears, when stars == 0) the rating for a subject, updating in place if one exists.
    func setRating(_ stars: Double, type: SubjectType, subjectID: String,
                   subjectName: String, artistName: String, coverURL: String?) {
        if let existing = rating(forSubjectID: subjectID) {
            if stars <= 0 {
                context.delete(existing)
            } else {
                existing.stars = stars
                existing.updatedAt = .now
            }
        } else if stars > 0 {
            context.insert(Rating(subjectType: type, subjectID: subjectID,
                                  subjectName: subjectName, artistName: artistName,
                                  coverURL: coverURL, stars: stars))
        }
        try? context.save()
    }

    // MARK: Reviews

    func review(forSubjectID id: String) -> Review? {
        var d = FetchDescriptor<Review>(predicate: #Predicate { $0.subjectID == id })
        d.fetchLimit = 1
        return (try? context.fetch(d))?.first
    }

    func saveReview(_ text: String, type: SubjectType, subjectID: String,
                    subjectName: String, artistName: String, coverURL: String?, stars: Double?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = review(forSubjectID: subjectID) {
            if trimmed.isEmpty {
                context.delete(existing)
            } else {
                existing.text = trimmed
                existing.stars = stars
                existing.updatedAt = .now
            }
        } else if !trimmed.isEmpty {
            context.insert(Review(subjectType: type, subjectID: subjectID,
                                  subjectName: subjectName, artistName: artistName,
                                  coverURL: coverURL, text: trimmed, stars: stars))
        }
        try? context.save()
    }

    // MARK: Lists

    func listEntries(forSubjectID id: String) -> [ListEntry] {
        let d = FetchDescriptor<ListEntry>(predicate: #Predicate { $0.subjectID == id })
        return (try? context.fetch(d)) ?? []
    }

    func isInList(_ kind: ListKind, customName: String?, subjectID: String) -> Bool {
        listEntries(forSubjectID: subjectID).contains {
            $0.kind == kind && ($0.customListName == customName || kind != .custom)
        }
    }

    /// Adds or removes a subject from a list bucket. Returns the resulting membership state.
    @discardableResult
    func toggleList(_ kind: ListKind, customName: String? = nil, type: SubjectType,
                    subjectID: String, subjectName: String, artistName: String,
                    coverURL: String?) -> Bool {
        let matches = listEntries(forSubjectID: subjectID).filter {
            $0.kind == kind && (kind != .custom || $0.customListName == customName)
        }
        if let first = matches.first {
            for m in matches { context.delete(m) }
            _ = first
            try? context.save()
            return false
        }
        let nextIndex = nextSortIndex(for: kind, customName: customName)
        context.insert(ListEntry(kind: kind, customListName: customName, subjectType: type,
                                 subjectID: subjectID, subjectName: subjectName,
                                 artistName: artistName, coverURL: coverURL, sortIndex: nextIndex))
        try? context.save()
        return true
    }

    private func nextSortIndex(for kind: ListKind, customName: String?) -> Int {
        let all = (try? context.fetch(FetchDescriptor<ListEntry>())) ?? []
        let inBucket = all.filter { $0.kind == kind && (kind != .custom || $0.customListName == customName) }
        return (inBucket.map(\.sortIndex).max() ?? -1) + 1
    }

    // MARK: Albums

    /// Finds an album by id, or inserts a new one. Used when attaching a vinyl copy or
    /// rating an album surfaced from Spotify/search.
    func upsertAlbum(id: String, title: String, artistName: String, spotifyID: String?,
                     coverURL: String?, releaseYear: Int?, isManual: Bool) -> Album {
        var d = FetchDescriptor<Album>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        if let found = (try? context.fetch(d))?.first {
            if found.coverURL == nil { found.coverURL = coverURL }
            return found
        }
        let album = Album(id: id, title: title, artistName: artistName, spotifyID: spotifyID,
                          coverURL: coverURL, releaseYear: releaseYear, isManual: isManual)
        context.insert(album)
        return album
    }
}
