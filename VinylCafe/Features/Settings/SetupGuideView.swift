import SwiftUI

/// Walks the user through the one-time Spotify developer-app registration needed to connect.
struct SetupGuideView: View {
    private let redirectURI = SpotifyConfig.redirectURI

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Connecting Spotify takes about five minutes and is free. You only do it once.")
                    .foregroundStyle(.secondary)

                step(1, "Open the dashboard",
                     "Go to developer.spotify.com/dashboard in a browser and log in with your Spotify account.")
                step(2, "Create an app",
                     "Click “Create app.” Give it any name and description (e.g. “Vinyl Cafe”).")
                step(3, "Set the Redirect URI",
                     "Add this exact Redirect URI, then save:")
                codeBlock(redirectURI)
                step(4, "Choose the API",
                     "Under “Which API/SDKs are you planning to use?”, tick “Web API.”")
                step(5, "Copy your Client ID",
                     "Open the app’s Settings on the dashboard and copy the Client ID. Paste it into Vinyl Cafe’s Settings screen.")
                step(6, "Add yourself as a user",
                     "In the dashboard under “User Management,” add your own Spotify account’s name and email. New apps are in development mode and only work for users you add (up to 25).")
                step(7, "Connect",
                     "Back in Vinyl Cafe, tap “Connect Spotify” and approve access.")

                Divider().padding(.vertical, 4)

                Text("About your analytics").font(.headline)
                Text("Spotify's API only returns your last 50 plays plus aggregated top tracks/artists — there's no full-history endpoint, and audio features were retired for new apps in 2024. So Vinyl Cafe builds history two ways:")
                    .foregroundStyle(.secondary)
                bullet("Sync grabs recent plays and grows your history from today forward.")
                bullet("Import your Spotify “Extended streaming history” data export for years of complete play-by-play data — the best way to get rich analytics fast.")
            }
            .padding()
        }
        .navigationTitle("Spotify Setup")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func step(_ n: Int, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(.accent, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(body).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private func codeBlock(_ text: String) -> some View {
        Text(text)
            .font(.callout.monospaced())
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .textSelection(.enabled)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "circle.fill").font(.system(size: 5)).padding(.top, 7)
            Text(text).font(.subheadline).foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack { SetupGuideView() }
}
