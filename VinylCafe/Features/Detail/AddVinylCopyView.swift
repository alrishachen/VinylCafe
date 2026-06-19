import SwiftUI
import SwiftData

/// Form for attaching a physical copy to an album. This is what makes an album
/// "owned on vinyl" and surfaces it in the Vinyl tab.
struct AddVinylCopyView: View {
    let album: Album

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var label = ""
    @State private var catalogNumber = ""
    @State private var pressingYear = ""
    @State private var color = "Black"
    @State private var condition: VinylCondition = .nearMint
    @State private var notes = ""

    private let colorOptions = ["Black", "Clear", "White", "Translucent Red", "Translucent Blue",
                                "Green", "Gold", "Splatter", "Picture Disc", "Marbled"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        CoverArtView(url: album.coverURL, size: 56)
                        VStack(alignment: .leading) {
                            Text(album.title).font(.headline).lineLimit(2)
                            Text(album.artistName).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Pressing") {
                    TextField("Label (e.g. XL Recordings)", text: $label)
                    TextField("Catalog number", text: $catalogNumber)
                    TextField("Pressing year", text: $pressingYear)
                        .keyboardType(.numberPad)
                    Picker("Color", selection: $color) {
                        ForEach(colorOptions, id: \.self) { Text($0).tag($0) }
                    }
                }

                Section("Condition") {
                    Picker("Condition", selection: $condition) {
                        ForEach(VinylCondition.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section("Notes") {
                    TextField("Anything worth remembering…", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle("Add Vinyl")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Add") { save() } }
            }
        }
    }

    private func save() {
        let copy = VinylCopy(
            album: album,
            label: label.trimmingCharacters(in: .whitespaces),
            catalogNumber: catalogNumber.trimmingCharacters(in: .whitespaces),
            pressingYear: Int(pressingYear),
            color: color,
            condition: condition,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        context.insert(copy)
        try? context.save()
        dismiss()
    }
}
