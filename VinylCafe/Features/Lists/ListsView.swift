import SwiftUI
import SwiftData

struct ListsView: View {
    @Environment(\.modelContext) private var context
    @Query private var entries: [ListEntry]
    @Query private var ratings: [Rating]
    @Query private var albums: [Album]

    @State private var selectedBucket: String = ListKind.wantToListen.rawValue
    @State private var sort: ListSort = .manual

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    EmptyStateView(systemImage: "list.bullet.rectangle",
                                   title: "Your lists are empty",
                                   message: "Open any album or song and tap “Want to Listen” or “Good Stuff” to start a list.")
                } else {
                    listBody
                }
            }
            .navigationTitle("Lists")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !entries.isEmpty { EditButton() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sort", selection: $sort) {
                            ForEach(ListSort.allCases) { Label($0.rawValue, systemImage: "arrow.up.arrow.down").tag($0) }
                        }
                    } label: { Image(systemName: "arrow.up.arrow.down.circle") }
                }
            }
            .navigationDestination(for: LibraryItem.self) { item in
                let subject = DetailSubject(type: item.type, id: item.subjectID, name: item.name,
                                            artist: item.artist, coverURL: item.coverURL, year: nil)
                SubjectDetailView(subject: subject, albumModel: albums.first { $0.id == item.subjectID })
            }
        }
    }

    private var listBody: some View {
        VStack(spacing: 0) {
            Picker("List", selection: $selectedBucket) {
                ForEach(buckets, id: \.key) { Text("\($0.title) (\($0.count))").tag($0.key) }
            }
            .pickerStyle(.menu)
            .padding(.horizontal)
            .frame(maxWidth: .infinity, alignment: .leading)

            List {
                ForEach(currentEntries) { entry in
                    NavigationLink(value: libraryItem(for: entry)) {
                        ListEntryRow(entry: entry, stars: starsByID[entry.subjectID])
                    }
                }
                .onDelete(perform: delete)
                .onMove(perform: sort == .manual ? move : nil)
            }
            .listStyle(.plain)
        }
    }

    // MARK: Buckets

    private struct Bucket { let key: String; let title: String; let count: Int }

    private var buckets: [Bucket] {
        var result: [Bucket] = []
        let standard: [ListKind] = [.wantToListen, .good]
        for kind in standard {
            let count = entries.filter { $0.kind == kind }.count
            result.append(Bucket(key: kind.rawValue, title: kind.title, count: count))
        }
        let customNames = Set(entries.filter { $0.kind == .custom }.compactMap { $0.customListName })
        for name in customNames.sorted() {
            let count = entries.filter { $0.kind == .custom && $0.customListName == name }.count
            result.append(Bucket(key: "custom:\(name)", title: name, count: count))
        }
        return result
    }

    private var currentEntries: [ListEntry] {
        let filtered: [ListEntry]
        if selectedBucket.hasPrefix("custom:") {
            let name = String(selectedBucket.dropFirst("custom:".count))
            filtered = entries.filter { $0.kind == .custom && $0.customListName == name }
        } else {
            let kind = ListKind(rawValue: selectedBucket) ?? .wantToListen
            filtered = entries.filter { $0.kind == kind }
        }
        return sortEntries(filtered)
    }

    private var starsByID: [String: Double] {
        Dictionary(ratings.map { ($0.subjectID, $0.stars) }, uniquingKeysWith: { a, _ in a })
    }

    private func sortEntries(_ list: [ListEntry]) -> [ListEntry] {
        switch sort {
        case .manual:    return list.sorted { $0.sortIndex < $1.sortIndex }
        case .dateAdded: return list.sorted { $0.addedAt > $1.addedAt }
        case .title:     return list.sorted { $0.subjectName.localizedCompare($1.subjectName) == .orderedAscending }
        case .artist:    return list.sorted { $0.artistName.localizedCompare($1.artistName) == .orderedAscending }
        case .rating:    return list.sorted { (starsByID[$0.subjectID] ?? 0) > (starsByID[$1.subjectID] ?? 0) }
        }
    }

    private func libraryItem(for entry: ListEntry) -> LibraryItem {
        LibraryItem(subjectID: entry.subjectID, type: entry.subjectType, name: entry.subjectName,
                    artist: entry.artistName, coverURL: entry.coverURL,
                    stars: starsByID[entry.subjectID], reviewText: nil, updatedAt: entry.addedAt)
    }

    // MARK: Mutations

    private func delete(_ offsets: IndexSet) {
        let list = currentEntries
        for index in offsets { context.delete(list[index]) }
        try? context.save()
    }

    private func move(_ offsets: IndexSet, _ destination: Int) {
        var list = currentEntries
        list.move(fromOffsets: offsets, toOffset: destination)
        for (i, entry) in list.enumerated() { entry.sortIndex = i }
        try? context.save()
    }
}

private struct ListEntryRow: View {
    let entry: ListEntry
    let stars: Double?
    var body: some View {
        HStack(spacing: 12) {
            CoverArtView(url: entry.coverURL, size: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.subjectName).font(.subheadline.weight(.medium)).lineLimit(1)
                Text(entry.artistName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                if let stars, stars > 0 { StarsView(stars: stars, size: 11) }
            }
            Spacer()
            Image(systemName: entry.subjectType.systemImage).font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    ListsView()
        .modelContainer(PreviewData.container)
}
