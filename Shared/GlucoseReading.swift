import Foundation

/// LibreLinkUp's `TrendArrow` value (1...5).
enum Trend: Int, Codable, Sendable {
    case unknown = 0
    case fallingFast = 1
    case falling = 2
    case stable = 3
    case rising = 4
    case risingFast = 5

    var arrow: String {
        switch self {
        case .fallingFast: "↓"
        case .falling: "↘"
        case .stable: "→"
        case .rising: "↗"
        case .risingFast: "↑"
        case .unknown: ""
        }
    }

    /// Shown under the number. Libre's arrows: ↓↑ more than 2 mg/dL a minute,
    /// ↘↗ 1–2 a minute, → less than 1.
    var label: String {
        switch self {
        case .fallingFast: "Falling fast"
        case .falling: "Falling"
        case .stable: "Steady"
        case .rising: "Rising"
        case .risingFast: "Rising fast"
        case .unknown: ""
        }
    }

    var spokenName: String {
        switch self {
        case .fallingFast: "falling fast"
        case .falling: "falling"
        case .stable: "steady"
        case .rising: "rising"
        case .risingFast: "rising fast"
        case .unknown: ""
        }
    }
}

struct GlucoseReading: Codable, Hashable, Sendable {
    var mgdl: Double
    var date: Date
    var trend: Trend
}

/// The latest reading plus recent history, as stored in the App Group.
struct GlucoseSnapshot: Codable, Sendable {
    var current: GlucoseReading
    /// Ascending by date, includes `current`.
    var history: [GlucoseReading]
    var fetchedAt: Date

    /// Change over roughly the last 5 minutes, in mg/dL per 5 min.
    /// Nil when there is no reading 3–15 minutes before the current one.
    var delta: Double? {
        let candidates = history.filter {
            let minutes = current.date.timeIntervalSince($0.date) / 60
            return minutes >= 3 && minutes <= 15
        }
        let target = current.date.addingTimeInterval(-5 * 60)
        guard let previous = candidates.min(by: {
            abs($0.date.timeIntervalSince(target)) < abs($1.date.timeIntervalSince(target))
        }) else { return nil }
        let minutes = current.date.timeIntervalSince(previous.date) / 60
        return (current.mgdl - previous.mgdl) * 5 / minutes
    }

    func isStale(at date: Date = .now, after minutes: Int) -> Bool {
        date.timeIntervalSince(current.date) > Double(minutes) * 60
    }

    func history(lastHours hours: Double, until date: Date = .now) -> [GlucoseReading] {
        let start = date.addingTimeInterval(-hours * 3600)
        return history.filter { $0.date >= start }
    }

    /// One value every `minutes`, so bars are evenly spaced even though LibreLinkUp's
    /// history mixes 15-minute points with 1-minute ones. Values between two readings
    /// are interpolated; gaps longer than 20 minutes stay empty.
    func sampled(every minutes: Double = 5, lastHours hours: Double = 3, until end: Date = .now) -> [GlucoseReading] {
        let points = history
        guard !points.isEmpty else { return [] }
        let step = minutes * 60
        let maxGap: TimeInterval = 20 * 60
        var result: [GlucoseReading] = []
        var index = 0
        var time = end.addingTimeInterval(-hours * 3600)
        while time <= end {
            while index + 1 < points.count, points[index + 1].date <= time { index += 1 }
            let before = points[index]
            if before.date <= time, index + 1 < points.count {
                let after = points[index + 1]
                let span = after.date.timeIntervalSince(before.date)
                if span <= maxGap {
                    let fraction = span > 0 ? time.timeIntervalSince(before.date) / span : 0
                    let value = before.mgdl + (after.mgdl - before.mgdl) * fraction
                    result.append(GlucoseReading(mgdl: value, date: time, trend: after.trend))
                }
            } else if before.date <= time, time.timeIntervalSince(before.date) <= step {
                result.append(GlucoseReading(mgdl: before.mgdl, date: time, trend: before.trend))
            }
            time = time.addingTimeInterval(step)
        }
        return result
    }
}

/// Summary of the last few hours for the watch's stats page.
struct GlucoseStats: Sendable {
    let hours: Double
    let average: Double
    let lowest: Double
    let highest: Double
    /// Share of time (0...1) in each range.
    let shares: [GlucoseRange: Double]

    /// Average and time in range use evenly spaced samples, so stretches with
    /// 1-minute readings don't count more than stretches with 15-minute ones.
    init?(_ snapshot: GlucoseSnapshot, settings: DisplaySettings, lastHours hours: Double = 12, until end: Date = .now) {
        let samples = snapshot.sampled(every: 5, lastHours: hours, until: end)
        let readings = snapshot.history(lastHours: hours, until: end)
        guard !samples.isEmpty, let lowest = readings.map(\.mgdl).min(), let highest = readings.map(\.mgdl).max()
        else { return nil }
        self.hours = hours
        self.lowest = lowest
        self.highest = highest
        average = samples.map(\.mgdl).reduce(0, +) / Double(samples.count)
        var counts: [GlucoseRange: Double] = [:]
        for sample in samples { counts[settings.range(of: sample.mgdl), default: 0] += 1 }
        shares = counts.mapValues { $0 / Double(samples.count) }
    }

    func share(_ range: GlucoseRange) -> Double { shares[range] ?? 0 }
}

/// Why the last fetch failed, in terms worth showing on a watch.
enum FetchProblem: Equatable, Sendable {
    /// No internet on the watch or phone.
    case offline
    /// LibreLinkUp is busy or returned an error; it'll likely work next time.
    case unavailable
    /// Needs you to do something (wrong login, accept terms...).
    case needsAction(String)

    /// Nil for cancellations: those happen when the app stops a fetch itself
    /// and are never worth showing.
    init?(_ error: Error) {
        if error is CancellationError { return nil }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .cancelled: return nil
            case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost,
                 .cannotConnectToHost, .dnsLookupFailed, .internationalRoamingOff, .dataNotAllowed:
                self = .offline
            default:
                self = .unavailable
            }
            return
        }
        switch error as? LibreLinkUpError {
        case .badCredentials, .termsNotAccepted, .noConnections, .notLoggedIn:
            self = .needsAction(error.localizedDescription)
        default:
            self = .unavailable
        }
    }

    var symbol: String {
        switch self {
        case .offline: "wifi.slash"
        case .unavailable: "icloud.slash"
        case .needsAction: "exclamationmark.triangle"
        }
    }
}

struct StepsSnapshot: Codable, Sendable {
    var count: Int
    var date: Date

    /// Steps only count for the day they were read on.
    func count(on day: Date = .now) -> Int {
        Calendar.current.isDate(date, inSameDayAs: day) ? count : 0
    }
}
