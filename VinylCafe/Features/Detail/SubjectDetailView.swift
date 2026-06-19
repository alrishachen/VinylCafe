import SwiftUI
import SwiftData

/// Lightweight description of the thing being shown — an album or a single track.
struct DetailSubject: Hashable {
    var type: SubjectType
    var id: String
    var name: String
    var artist: String
    var coverURL: String?
    var year: Int?

    static func from(album: Album) -> DetailSubject {
        .init(type: .album, id: album.id, name: album.title, artist: album.artistName,
              coverURL: album.coverURL, year: album.releaseYear)
    }
    static func from(track: Track) -> DetailSubject {
        .init(type: .track, id: track.id, name: track.title, artist: track.artistName,
              coverURL: track.coverURL, year: nil)
    }
}

/// The one screen used everywhere to rate, review, list, and (for albums) manage vinyl
/// copies. Whether you arrive from the Library, the Vinyl grid, search, or the Dashboard,
/// it's the same experience.
struct SubjectDetailView: View {
    let subject: DetailSubject
    /// Provided when we have a backing Album row (enables the vinyl section).
    var albumModel: Album?

    @Environment(\.modelContext) private var context
    @State private var stars: Double = 0
    @State private var showingReview = false
    @State private var reviewText: String = ""
    @State private var showingAddVinyl = false

    private var actions: LibraryActions { LibraryActions(context: context) }

    init(subject: DetailSubject, albumModel: Album? = nil) {
        self.subject = subject
        self.albumModel = albumModel
    }
    init(album: Album) {
        self.subject = .from(album: album)
        self.albumModel = album
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                ratingSection
                reviewSection
                listSection
                if subject.type == .album { vinylSection }
            }
            .padding()
        }
        .navigationTitle(subject.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
        .sheet(isPresented: $showingReview) {
            ReviewEditorView(subject: subject, stars: stars, initialText: reviewText) { saved in
                reviewText = saved
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingAddVinyl) {
            if let album = backingAlbum() {
                AddVinylCopyView(album: album)
            }
        }
    }

    // MARK: Sections

    private var header: some View {
        VStack(spacing: 12) {
            CoverArtView(url: subject.coverURL, size: 180, cornerRadius: 14)
                .shadow(radius: 8, y: 4)
            VStack(spacing: 4) {
                Text(subject.name).font(.title2.bold()).multilineTextAlignment(.center)
                Text(subject.artist).font(.headline).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Label(subject.type.label, systemImage: subject.type.systemImage)
                    if let year = subject.year { Text("· \(String(year))") }
                    if albumModel?.ownedOnVinyl == true {
                        Text("· ").foregroundStyle(.secondary)
                        Label("On Vinyl", systemImage: "opticaldisc")
                            .foregroundStyle(.accent)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var ratingSection: some View {
        VStack(spacing: 10) {
            Text("Your Rating").font(.headline)
            StarRatingView(stars: Binding(
                get: { stars },
                set: { newValue in
                    stars = newValue
                    actions.setRating(newValue, type: subject.type, subjectID: subject.id,
                                      subjectName: subject.name, artistName: subject.artist,
                                      coverURL: subject.coverURL)
                }
            ))
            Text(stars > 0 ? String(format: "%.1f / 5", stars) : "Tap to rate")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Review").font(.headline)
                Spacer()
                Button(reviewText.isEmpty ? "Write" : "Edit") { showingReview = true }
                    .font(.subheadline)
            }
            if reviewText.isEmpty {
                Text("No review yet.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                Text(reviewText)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var listSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Lists").font(.headline)
            HStack(spacing: 10) {
                listToggle(.wantToListen)
                listToggle(.good)
            }
        }
    }

    private func listToggle(_ kind: ListKind) -> some View {
        let isIn = actions.isInList(kind, customName: nil, subjectID: subject.id)
        return Button {
            _ = actions.toggleList(kind, type: subject.type, subjectID: subject.id,
                                   subjectName: subject.name, artistName: subject.artist,
                                   coverURL: subject.coverURL)
        } label: {
            Label(kind.title, systemImage: isIn ? "checkmark.circle.fill" : kind.systemImage)
                .font(.subheadline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(isIn ? .accentColor : .secondary)
    }

    private var vinylSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Vinyl").font(.headline)
                Spacer()
                Button {
                    showingAddVinyl = true
                } label: { Label("Add Copy", systemImage: "plus") }
                    .font(.subheadline)
            }

            if let album = albumModel, album.ownedOnVinyl {
                ForEach(album.vinylCopies.sorted(by: { $0.addedAt < $1.addedAt })) { copy in
                    VinylCopyRow(copy: copy)
                }
            } else {
                Text("You don't own this on vinyl yet.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Logic

    private func load() {
        stars = actions.rating(forSubjectID: subject.id)?.stars ?? 0
        reviewText = actions.review(forSubjectID: subject.id)?.text ?? ""
    }

    /// Returns a persisted Album to attach vinyl copies to, creating one if this subject
    /// only existed transiently (e.g. surfaced from search).
    private func backingAlbum() -> Album? {
        if let albumModel { return albumModel }
        guard subject.type == .album else { return nil }
        let album = actions.upsertAlbum(id: subject.id, title: subject.name,
                                        artistName: subject.artist, spotifyID: nil,
                                        coverURL: subject.coverURL, releaseYear: subject.year,
                                        isManual: true)
        return album
    }
}

private struct VinylCopyRow: View {
    let copy: VinylCopy
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "opticaldisc.fill")
                .font(.title2)
                .foregroundStyle(.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text([copy.label, copy.catalogNumber].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(copy.label.isEmpty && copy.catalogNumber.isEmpty ? .secondary : .primary)
                Text("\(copy.color) · \(copy.condition.rawValue)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(copy.condition.abbreviation)
                .font(.caption.bold())
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(.accent.opacity(0.15), in: Capsule())
                .foregroundStyle(.accent)
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        let album = try! PreviewData.container.mainContext.fetch(FetchDescriptor<Album>()).first!
        SubjectDetailView(album: album)
    }
    .modelContainer(PreviewData.container)
}
