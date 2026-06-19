import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(SpotifyController.self) private var spotify
    @Query private var plays: [PlayRecord]

    @State private var clientID = SpotifyConfig.clientID
    @State private var showingImporter = false
    @State private var importMessage: String?
    @State private var showingImportAlert = false

    var body: some View {
        NavigationStack {
            Form {
                spotifySection
                if spotify.isConnected { syncSection }
                importSection
                dataSection
                aboutSection
            }
            .navigationTitle("Settings")
            .fileImporter(isPresented: $showingImporter,
                          allowedContentTypes: [.json],
                          allowsMultipleSelection: true) { handleImport($0) }
            .alert("Import Complete", isPresented: $showingImportAlert) {
                Button("OK", role: .cancel) {}
            } message: { Text(importMessage ?? "") }
        }
    }

    // MARK: Spotify connection

    private var spotifySection: some View {
        Section {
            HStack {
                Label("Status", systemImage: "dot.radiowaves.left.and.right")
                Spacer()
                Text(statusText).foregroundStyle(statusColor)
            }
            if let name = spotify.profileName {
                HStack { Text("Account"); Spacer(); Text(name).foregroundStyle(.secondary) }
            }

            if !SpotifyConfig.isConfigured || spotify.status == .notConfigured {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Spotify Client ID").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        TextField("Paste your Client ID", text: $clientID)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        Button("Save") {
                            SpotifyConfig.clientID = clientID
                            spotify.refreshStatus()
                        }
                        .disabled(clientID.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    Text("Get one free at developer.spotify.com — see the setup guide below.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }

            connectionButton
            if let error = spotify.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        } header: {
            Text("Spotify")
        }
    }

    @ViewBuilder
    private var connectionButton: some View {
        switch spotify.status {
        case .notConfigured:
            EmptyView()
        case .disconnected:
            Button { Task { await spotify.connect() } } label: {
                Label("Connect Spotify", systemImage: "link")
            }
        case .connecting:
            HStack { ProgressView(); Text("Connecting…").foregroundStyle(.secondary) }
        case .connected:
            Button(role: .destructive) { spotify.disconnect() } label: {
                Label("Disconnect", systemImage: "link.badge.plus")
            }
        }
    }

    // MARK: Sync

    private var syncSection: some View {
        Section("Sync") {
            Button {
                Task { await spotify.syncNow(context: context) }
            } label: {
                HStack {
                    Label("Sync Recently Played", systemImage: "arrow.clockwise")
                    Spacer()
                    if spotify.isSyncing { ProgressView() }
                }
            }
            .disabled(spotify.isSyncing)
            if let summary = spotify.lastSyncSummary {
                Text(summary).font(.caption).foregroundStyle(.secondary)
            }
            Text("Spotify only exposes your last 50 plays, so sync often to keep history complete.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: Import

    private var importSection: some View {
        Section("Import History") {
            Button {
                showingImporter = true
            } label: {
                Label("Import Spotify Data Export", systemImage: "square.and.arrow.down")
            }
            Text("Request your “Extended streaming history” from Spotify’s privacy page, then import the JSON files here for your full listening history.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: Data

    private var dataSection: some View {
        Section("Your Data") {
            HStack { Text("Plays logged"); Spacer(); Text("\(plays.count)").foregroundStyle(.secondary) }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            NavigationLink {
                SetupGuideView()
            } label: {
                Label("Spotify Setup Guide", systemImage: "book")
            }
            HStack { Text("Version"); Spacer(); Text("1.0").foregroundStyle(.secondary) }
            Text("Vinyl Cafe keeps all your ratings, reviews, lists, and records on your device.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: Helpers

    private var statusText: String {
        switch spotify.status {
        case .notConfigured: return "Not set up"
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting…"
        case .connected: return "Connected"
        }
    }
    private var statusColor: Color {
        switch spotify.status {
        case .connected: return .green
        case .connecting: return .orange
        default: return .secondary
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            do {
                let r = try ImportService.importFiles(urls, context: context)
                importMessage = "Parsed \(r.filesParsed) file\(r.filesParsed == 1 ? "" : "s"). Added \(r.added) plays" +
                    (r.skipped > 0 ? ", skipped \(r.skipped) duplicates." : ".")
            } catch {
                importMessage = "Couldn't import: \(error.localizedDescription)"
            }
            showingImportAlert = true
        case .failure(let error):
            importMessage = error.localizedDescription
            showingImportAlert = true
        }
    }
}

#Preview {
    SettingsView()
        .environment(SpotifyController())
        .modelContainer(PreviewData.container)
}
