import SwiftUI
import SwiftData

struct LibraryView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case all = "All", rated = "Rated", reviewed = "Reviewed"
        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var context
    @Query(sort: \Rating.updatedAt, order: .reverse) private var ratings: [Rating]
    @Query(sort: \Review.updatedAt, order: .reverse) private var reviews: [Review]
    @Query private var albums: [Album]

    @State private var filter: Filter = .all
    @State private var search = ""

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    EmptyStateView(systemImage: "star.square.on.square",
                                   title: "Nothing rated yet",
                                   message: "Rate or review an album or song and it'll show up here.")
                } else {
                    List {
                        ForEach(items) { item in
                            NavigationLink(value: item) {
                                LibraryRow(item: item)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Library")
            .searchable(text: $search, prompt: "Search your library")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Filter", selection: $filter) {
                        ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationDestination(for: LibraryItem.self) { item in
                detail(for: item)
            }
        }
    }

    // MARK: Data

    private var items: [LibraryItem] {
        var byID: [String: LibraryItem] = [:]
        for r in ratings {
            byID[r.subjectID] = LibraryItem(subjectID: r.subjectID, type: r.subjectType,
                                            name: r.subjectName, artist: r.artistName,
                                            coverURL: r.coverURL, stars: r.stars, reviewText: nil,
                                            updatedAt: r.updatedAt)
        }
        for rev in reviews {
            if var existing = byID[rev.subjectID] {
                existing.reviewText = rev.text
                existing.updatedAt = max(existing.updatedAt, rev.updatedAt)
                byID[rev.subjectID] = existing
            } else {
                byID[rev.subjectID] = LibraryItem(subjectID: rev.subjectID, type: rev.subjectType,
                                                  name: rev.subjectName, artist: rev.artistName,
                                                  coverURL: rev.coverURL, stars: rev.stars,
                                                  reviewText: rev.text, updatedAt: rev.updatedAt)
            }
        }

        return byID.values
            .filter { item in
                switch filter {
                case .all: return true
                case .rated: return item.stars != nil && item.stars! > 0
                case .reviewed: return !(item.reviewText ?? "").isEmpty
                }
            }
            .filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)
                || $0.artist.localizedCaseInsensitiveContains(search) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    @ViewBuilder
    private func detail(for item: LibraryItem) -> some View {
        let subject = DetailSubject(type: item.type, id: item.subjectID, name: item.name,
                                    artist: item.artist, coverURL: item.coverURL, year: nil)
        SubjectDetailView(subject: subject, albumModel: albums.first { $0.id == item.subjectID })
    }
}

struct LibraryItem: Identifiable, Hashable {
    var id: String { subjectID }
    let subjectID: String
    let type: SubjectType
    let name: String
    let artist: String
    let coverURL: String?
    var stars: Double?
    var reviewText: String?
    var updatedAt: Date
}

private struct LibraryRow: View {
    let item: LibraryItem
    var body: some View {
        HStack(spacing: 12) {
            CoverArtView(url: item.coverURL, size: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(item.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                if let stars = item.stars, stars > 0 {
                    StarsView(stars: stars, size: 12)
                }
                if let review = item.reviewText, !review.isEmpty {
                    Text(review).font(.caption2).foregroundStyle(.secondary).lineLimit(1).italic()
                }
            }
            Spacer()
            Image(systemName: item.type.systemImage)
                .font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    LibraryView()
        .modelContainer(PreviewData.container)
}
