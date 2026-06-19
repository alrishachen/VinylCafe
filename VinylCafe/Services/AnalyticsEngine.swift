import Foundation

/// Aggregated listening stats derived from the local `PlayRecord` store. Pure value types
/// so they're trivial to compute, cache, and preview.

struct NamedCount: Identifiable {
    let id = UUID()
    let name: String
    let subtitle: String?
    let count: Int
    let minutes: Int
}

struct HourBucket: Identifiable { let id = UUID(); let hour: Int; let count: Int }
struct WeekdayBucket: Identifiable { let id = UUID(); let weekday: Int; let label: String; let count: Int }
struct MonthBucket: Identifiable { let id = UUID(); let date: Date; let label: String; let count: Int }

struct ListeningSummary {
    var totalPlays = 0
    var totalMinutes = 0
    var distinctArtists = 0
    var distinctTracks = 0
    var currentStreakDays = 0
    var firstPlay: Date?
    var lastPlay: Date?

    var topArtists: [NamedCount] = []
    var topTracks: [NamedCount] = []
    var topAlbums: [NamedCount] = []
    var byHour: [HourBucket] = []
    var byWeekday: [WeekdayBucket] = []
    var byMonth: [MonthBucket] = []

    var isEmpty: Bool { totalPlays == 0 }
    var totalHours: Int { totalMinutes / 60 }
}

enum AnalyticsEngine {
    private static let weekdaySymbols = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    static func summarize(_ plays: [PlayRecord], calendar: Calendar = .current) -> ListeningSummary {
        var summary = ListeningSummary()
        guard !plays.isEmpty else { return summary }

        summary.totalPlays = plays.count
        summary.totalMinutes = plays.reduce(0) { $0 + $1.msPlayed } / 60_000

        // Top artists / tracks / albums.
        summary.topArtists = topGroups(plays, key: { $0.artistName }, subtitle: { _ in nil }).prefix(8).map { $0 }
        summary.topTracks = topGroups(plays, key: { "\($0.trackName)—\($0.artistName)" },
                                      display: { $0.trackName }, subtitle: { $0.artistName }).prefix(8).map { $0 }
        summary.topAlbums = topGroups(plays.filter { $0.albumName != nil },
                                      key: { ($0.albumName ?? "") + "—" + $0.artistName },
                                      display: { $0.albumName ?? "" }, subtitle: { $0.artistName }).prefix(8).map { $0 }

        summary.distinctArtists = Set(plays.map(\.artistName)).count
        summary.distinctTracks = Set(plays.map { "\($0.trackName)—\($0.artistName)" }).count

        let sorted = plays.map(\.playedAt).sorted()
        summary.firstPlay = sorted.first
        summary.lastPlay = sorted.last

        // By hour of day.
        var hours = Array(repeating: 0, count: 24)
        for p in plays { hours[calendar.component(.hour, from: p.playedAt)] += 1 }
        summary.byHour = hours.enumerated().map { HourBucket(hour: $0.offset, count: $0.element) }

        // By weekday.
        var weekdays = Array(repeating: 0, count: 8)
        for p in plays { weekdays[calendar.component(.weekday, from: p.playedAt)] += 1 }
        summary.byWeekday = (1...7).map { WeekdayBucket(weekday: $0, label: weekdaySymbols[$0], count: weekdays[$0]) }

        // By month (last 12 months present in data).
        summary.byMonth = monthly(plays, calendar: calendar)

        // Current streak: consecutive days up to today with ≥1 play.
        summary.currentStreakDays = streak(plays, calendar: calendar)

        return summary
    }

    // MARK: Helpers

    private static func topGroups(_ plays: [PlayRecord],
                                  key: (PlayRecord) -> String,
                                  display: ((PlayRecord) -> String)? = nil,
                                  subtitle: (PlayRecord) -> String?) -> [NamedCount] {
        var counts: [String: (name: String, subtitle: String?, count: Int, ms: Int)] = [:]
        for p in plays {
            let k = key(p)
            let name = display?(p) ?? p.artistName
            var entry = counts[k] ?? (name: name, subtitle: subtitle(p), count: 0, ms: 0)
            entry.count += 1
            entry.ms += p.msPlayed
            counts[k] = entry
        }
        return counts.values
            .map { NamedCount(name: $0.name, subtitle: $0.subtitle, count: $0.count, minutes: $0.ms / 60_000) }
            .sorted { $0.count > $1.count }
    }

    private static func monthly(_ plays: [PlayRecord], calendar: Calendar) -> [MonthBucket] {
        let fmt = DateFormatter(); fmt.dateFormat = "MMM"
        var buckets: [Date: Int] = [:]
        for p in plays {
            let comps = calendar.dateComponents([.year, .month], from: p.playedAt)
            if let monthStart = calendar.date(from: comps) {
                buckets[monthStart, default: 0] += 1
            }
        }
        return buckets.keys.sorted().suffix(12).map {
            MonthBucket(date: $0, label: fmt.string(from: $0), count: buckets[$0] ?? 0)
        }
    }

    private static func streak(_ plays: [PlayRecord], calendar: Calendar) -> Int {
        let days = Set(plays.map { calendar.startOfDay(for: $0.playedAt) })
        guard !days.isEmpty else { return 0 }
        var streak = 0
        var day = calendar.startOfDay(for: Date())
        // Allow the streak to count even if nothing's been played yet today.
        if !days.contains(day) {
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
            if !days.contains(day) { return 0 }
        }
        while days.contains(day) {
            streak += 1
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return streak
    }
}
