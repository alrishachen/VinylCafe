import SwiftUI
import SwiftData

/// Adds a record to the collection by either searching Spotify (when connected) or
/// entering it by hand. Either path creates a normal Album, then collects the physical
/// copy's details — so the result is a first-class album that happens to be on vinyl.
struct AddRecordView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case search = "Search Spotify", manual = "Enter Manually"
        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var context
    @Environment(SpotifyController.self) private var spotify
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode = .search
    @State private var query = ""
    @State private var results: [SpotifyAlbumFull] = []
    @State private var searching = false
    @State private var searchError: String?

    @State private var manualTitle = ""
    @State private var manualArtist = ""
    @State private var manualYear = ""

    @State private var albumToAdd: Album?

    var body: some View {
        NavigationStack {
            Form {
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)

                if mode == .search { searchSection } else { manualSection }
            }
            .navigationTitle("Add a Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .navigationDestination(item: $albumToAdd) { album in
                AddVinylCopyView(album: album)
            }
        }
    }

    // MARK: Search

    private var searchSection: some View {
        Group {
            Section {
                HStack {
                    TextField("Album or artist", text: $query)
                        .onSubmit(runSearch)
                        .autocorrectionDisabled()
                    Button(action: runSearch) { Image(systemName: "magnifyingglass") }
                }
            }

            if !spotify.isConnected {
                Section {
                    Label("Connect Spotify in Settings to search, or switch to “Enter Manually”.",
                          systemImage: "info.circle")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }

            if searching { Section { ProgressView() } }
            if let searchError { Section { Text(searchError).font(.footnote).foregroundStyle(.red) } }

            if !results.isEmpty {
                Section("Results") {
                    ForEach(results, id: \.id) { result in
                        Button { pick(result) } label: {
                            HStack(spacing: 12) {
                                CoverArtView(url: result.coverURL, size: 48)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.name).font(.subheadline.weight(.medium)).lineLimit(1)
                                    Text(result.primaryArtist + (result.year.map { " · \($0)" } ?? ""))
                                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "plus.circle").foregroundStyle(.accent)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func runSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, spotify.isConnected else { return }
        searching = true
        searchError = nil
        Task {
            defer { searching = false }
            do { results = try await spotify.api.searchAlbums(trimmed) }
            catch { searchError = error.localizedDescription }
        }
    }

    private func pick(_ result: SpotifyAlbumFull) {
        let album = LibraryActions(context: context).upsertAlbum(
            id: result.id, title: result.name, artistName: result.primaryArtist,
            spotifyID: result.id, coverURL: result.coverURL, releaseYear: result.year, isManual: false)
        albumToAdd = album
    }

    // MARK: Manual

    private var manualSection: some View {
        Group {
            Section("Album") {
                TextField("Title", text: $manualTitle)
                TextField("Artist", text: $manualArtist)
                TextField("Release year", text: $manualYear).keyboardType(.numberPad)
            }
            Section {
                Button("Next: Copy Details") { createManual() }
                    .disabled(manualTitle.trimmingCharacters(in: .whitespaces).isEmpty
                              || manualArtist.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func createManual() {
        let album = Album(title: manualTitle.trimmingCharacters(in: .whitespaces),
                          artistName: manualArtist.trimmingCharacters(in: .whitespaces),
                          releaseYear: Int(manualYear),
                          isManual: true)
        context.insert(album)
        try? context.save()
        albumToAdd = album
    }
}
