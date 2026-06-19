import SwiftUI
import SwiftData

@main
struct VinylCafeApp: App {
    let container: ModelContainer
    @State private var spotify = SpotifyController()

    init() {
        do {
            container = try ModelContainer(
                for: Album.self, Track.self, Artist.self, VinylCopy.self,
                PlayRecord.self, Rating.self, Review.self, ListEntry.self
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        SampleData.seedIfNeeded(container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(spotify)
                .tint(.accentColor)
        }
        .modelContainer(container)
    }
}
