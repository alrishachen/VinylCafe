import Foundation
import SwiftData

/// In-memory, seeded container for SwiftUI previews.
enum PreviewData {
    static let container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Album.self, Track.self, Artist.self, VinylCopy.self,
            PlayRecord.self, Rating.self, Review.self, ListEntry.self,
            configurations: config
        )
        SampleData.seed(ModelContext(container))
        return container
    }()
}
