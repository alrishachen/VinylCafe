import SwiftUI
import SwiftData

/// Sheet for writing or editing a review of a subject. Saving an empty review deletes it.
struct ReviewEditorView: View {
    let subject: DetailSubject
    let stars: Double
    let initialText: String
    var onSave: (String) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    CoverArtView(url: subject.coverURL, size: 44)
                    VStack(alignment: .leading) {
                        Text(subject.name).font(.headline).lineLimit(1)
                        Text(subject.artist).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                .padding(.horizontal)

                TextEditor(text: $text)
                    .padding(8)
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal)
                    .frame(maxHeight: .infinity)
            }
            .padding(.top)
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .onAppear { text = initialText }
        }
    }

    private func save() {
        LibraryActions(context: context).saveReview(
            text, type: subject.type, subjectID: subject.id, subjectName: subject.name,
            artistName: subject.artist, coverURL: subject.coverURL, stars: stars > 0 ? stars : nil
        )
        onSave(text.trimmingCharacters(in: .whitespacesAndNewlines))
        dismiss()
    }
}
