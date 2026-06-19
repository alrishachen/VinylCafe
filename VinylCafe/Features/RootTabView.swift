import SwiftUI

struct RootTabView: View {
    @State private var selection: Int = Int(ProcessInfo.processInfo.environment["START_TAB"] ?? "") ?? 0

    var body: some View {
        TabView(selection: $selection) {
            DashboardView()
                .tabItem { Label("Stats", systemImage: "chart.bar.xaxis") }
                .tag(0)

            LibraryView()
                .tabItem { Label("Library", systemImage: "star.square.on.square") }
                .tag(1)

            ListsView()
                .tabItem { Label("Lists", systemImage: "list.bullet.rectangle") }
                .tag(2)

            VinylView()
                .tabItem { Label("Vinyl", systemImage: "opticaldisc") }
                .tag(3)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(4)
        }
    }
}

#Preview {
    RootTabView()
        .environment(SpotifyController())
        .modelContainer(PreviewData.container)
}
