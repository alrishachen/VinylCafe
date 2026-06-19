import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Environment(SpotifyController.self) private var spotify
    @Query private var plays: [PlayRecord]

    private var summary: ListeningSummary {
        AnalyticsEngine.summarize(plays)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if !spotify.isConnected { connectBanner }

                    if summary.isEmpty {
                        EmptyStateView(systemImage: "chart.bar.xaxis",
                                       title: "No listening data yet",
                                       message: "Connect Spotify and sync, or import your Spotify data export, to see your stats here.")
                            .padding(.top, 40)
                    } else {
                        statGrid
                        if !summary.topArtists.isEmpty { topArtistsCard }
                        if summary.byMonth.count > 1 { monthlyCard }
                        hourlyCard
                        weekdayCard
                        if !summary.topTracks.isEmpty { topTracksCard }
                        if !summary.topAlbums.isEmpty { topAlbumsCard }
                        coverageFootnote
                    }
                }
                .padding()
            }
            .navigationTitle("Your Stats")
            .toolbar {
                if spotify.isConnected {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task { await spotify.syncNow(context: context) }
                        } label: {
                            if spotify.isSyncing { ProgressView() }
                            else { Image(systemName: "arrow.clockwise") }
                        }
                        .disabled(spotify.isSyncing)
                    }
                }
            }
        }
    }

    // MARK: Cards

    private var connectBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "music.note.list").font(.title2).foregroundStyle(.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Connect Spotify").font(.subheadline.weight(.semibold))
                Text("Sync your plays for live analytics. Until then, you're seeing sample data.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var statGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(value: "\(summary.totalPlays)", label: "Plays", systemImage: "play.circle")
            StatCard(value: "\(summary.totalHours)h", label: "Listened", systemImage: "clock")
            StatCard(value: "\(summary.currentStreakDays)", label: "Day Streak", systemImage: "flame")
            StatCard(value: "\(summary.distinctArtists)", label: "Artists", systemImage: "person.2")
            StatCard(value: "\(summary.distinctTracks)", label: "Songs", systemImage: "music.note")
            StatCard(value: "\(summary.topAlbums.count)", label: "Albums", systemImage: "square.stack")
        }
    }

    private var topArtistsCard: some View {
        CardSection(title: "Top Artists", systemImage: "person.2.fill") {
            VStack(spacing: 6) {
                ForEach(Array(summary.topArtists.prefix(6).enumerated()), id: \.element.id) { i, a in
                    RankRow(rank: i + 1, title: a.name, subtitle: nil, trailing: "\(a.count) plays")
                }
            }
        }
    }

    private var topTracksCard: some View {
        CardSection(title: "Top Songs", systemImage: "music.note") {
            VStack(spacing: 6) {
                ForEach(Array(summary.topTracks.prefix(6).enumerated()), id: \.element.id) { i, t in
                    RankRow(rank: i + 1, title: t.name, subtitle: t.subtitle, trailing: "\(t.count)")
                }
            }
        }
    }

    private var topAlbumsCard: some View {
        CardSection(title: "Top Albums", systemImage: "square.stack.fill") {
            VStack(spacing: 6) {
                ForEach(Array(summary.topAlbums.prefix(6).enumerated()), id: \.element.id) { i, a in
                    RankRow(rank: i + 1, title: a.name, subtitle: a.subtitle, trailing: "\(a.count)")
                }
            }
        }
    }

    private var monthlyCard: some View {
        CardSection(title: "Plays by Month", systemImage: "calendar") {
            Chart(summary.byMonth) { bucket in
                BarMark(x: .value("Month", bucket.label), y: .value("Plays", bucket.count))
                    .foregroundStyle(.accent)
                    .cornerRadius(4)
            }
            .frame(height: 160)
        }
    }

    private var hourlyCard: some View {
        CardSection(title: "When You Listen", systemImage: "clock.fill") {
            Chart(summary.byHour) { bucket in
                BarMark(x: .value("Hour", bucket.hour), y: .value("Plays", bucket.count))
                    .foregroundStyle(.accent.opacity(0.85))
            }
            .chartXScale(domain: 0...23)
            .chartXAxis {
                AxisMarks(values: [0, 6, 12, 18, 23]) { value in
                    AxisValueLabel { if let h = value.as(Int.self) { Text(hourLabel(h)) } }
                }
            }
            .frame(height: 150)
        }
    }

    private var weekdayCard: some View {
        CardSection(title: "By Day of Week", systemImage: "calendar.day.timeline.left") {
            Chart(summary.byWeekday) { bucket in
                BarMark(x: .value("Day", bucket.label), y: .value("Plays", bucket.count))
                    .foregroundStyle(.accent)
                    .cornerRadius(4)
            }
            .frame(height: 150)
        }
    }

    private var coverageFootnote: some View {
        Group {
            if let first = summary.firstPlay, let last = summary.lastPlay {
                Text("Based on \(summary.totalPlays) plays from \(first.formatted(date: .abbreviated, time: .omitted)) to \(last.formatted(date: .abbreviated, time: .omitted)).")
                    .font(.caption2).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private func hourLabel(_ h: Int) -> String {
        switch h {
        case 0: return "12a"
        case 12: return "12p"
        case let x where x < 12: return "\(x)a"
        default: return "\(h - 12)p"
        }
    }
}

/// Titled container card used throughout the Dashboard.
struct CardSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    DashboardView()
        .environment(SpotifyController())
        .modelContainer(PreviewData.container)
}
