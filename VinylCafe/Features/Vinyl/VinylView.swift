import SwiftUI
import SwiftData

struct VinylView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Album.addedAt, order: .reverse) private var albums: [Album]
    @State private var showingAdd = false

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]

    private var records: [Album] { albums.filter { $0.ownedOnVinyl } }
    private var copyCount: Int { records.reduce(0) { $0 + $1.vinylCopies.count } }

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    EmptyStateView(systemImage: "opticaldisc",
                                   title: "No records yet",
                                   message: "Add a record to your collection. They behave like any album — rate, review, and list them too.",
                                   actionTitle: "Add a Record") { showingAdd = true }
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(records) { album in
                                NavigationLink(value: album.id) {
                                    VinylTile(album: album)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Vinyl")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                }
                if !records.isEmpty {
                    ToolbarItem(placement: .bottomBar) {
                        Text("\(records.count) album\(records.count == 1 ? "" : "s") · \(copyCount) record\(copyCount == 1 ? "" : "s")")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationDestination(for: String.self) { id in
                if let album = albums.first(where: { $0.id == id }) {
                    SubjectDetailView(album: album)
                }
            }
            .sheet(isPresented: $showingAdd) { AddRecordView() }
        }
    }
}

private struct VinylTile: View {
    let album: Album
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                CoverArtView(url: album.coverURL, size: 150, cornerRadius: 12)
                    .frame(maxWidth: .infinity)
                if album.vinylCopies.count > 1 {
                    Text("×\(album.vinylCopies.count)")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(6)
                }
            }
            Text(album.title).font(.subheadline.weight(.semibold)).lineLimit(1)
            Text(album.artistName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            if let copy = album.vinylCopies.first {
                Text("\(copy.color) · \(copy.condition.abbreviation)")
                    .font(.caption2).foregroundStyle(.accent)
            }
        }
    }
}

#Preview {
    VinylView()
        .environment(SpotifyController())
        .modelContainer(PreviewData.container)
}
