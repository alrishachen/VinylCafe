import Foundation
import Observation
import SwiftData

/// App-wide Spotify state and the actions the UI triggers. Injected into the SwiftUI
/// environment so any screen can observe the connection and kick off a sync/import.
@MainActor
@Observable
final class SpotifyController {
    enum Status: Equatable {
        case notConfigured     // no Client ID yet
        case disconnected      // configured but signed out
        case connecting
        case connected
    }

    @ObservationIgnored private let auth = SpotifyAuth()
    @ObservationIgnored private(set) var api: SpotifyAPIClient

    var status: Status = .notConfigured
    var profileName: String?
    var errorMessage: String?
    var lastSyncSummary: String?
    var isSyncing = false

    // Instant post-login lists (don't require accumulated history).
    var topArtists: [SpotifyArtist] = []
    var topTracks: [SpotifyTrack] = []
    var topRange: SpotifyTimeRange = .mediumTerm

    init() {
        api = SpotifyAPIClient(auth: auth)
        refreshStatus()
    }

    func refreshStatus() {
        if !SpotifyConfig.isConfigured {
            status = .notConfigured
        } else if auth.isAuthenticated {
            status = .connected
        } else {
            status = .disconnected
        }
    }

    var isConnected: Bool { status == .connected }

    // MARK: Actions

    func connect() async {
        errorMessage = nil
        guard SpotifyConfig.isConfigured else { status = .notConfigured; return }
        status = .connecting
        do {
            try await auth.signIn()
            status = .connected
            await loadProfile()
            await loadTopItems()
        } catch SpotifyAuthError.userCancelled {
            refreshStatus()
        } catch {
            errorMessage = error.localizedDescription
            refreshStatus()
        }
    }

    func disconnect() {
        auth.signOut()
        profileName = nil
        topArtists = []
        topTracks = []
        refreshStatus()
    }

    func loadProfile() async {
        guard isConnected else { return }
        do { profileName = try await api.currentUser().display_name }
        catch { errorMessage = error.localizedDescription }
    }

    func loadTopItems() async {
        guard isConnected else { return }
        do {
            async let artists = api.topArtists(topRange)
            async let tracks = api.topTracks(topRange)
            topArtists = try await artists
            topTracks = try await tracks
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func syncNow(context: ModelContext) async {
        guard isConnected else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            let added = try await SyncService.sync(api: api, context: context)
            lastSyncSummary = added == 0 ? "Up to date — no new plays." : "Added \(added) new play\(added == 1 ? "" : "s")."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
