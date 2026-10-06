import Foundation

/// Sample data for screenshots, so the app can be shown without a LibreLinkUp login.
/// Debug builds only: launch with `-demo`, and `-page 1` or `-page 2` to open on page 2 or 3.
enum DemoMode {
    #if DEBUG
    static let isOn = ProcessInfo.processInfo.arguments.contains("-demo")

    static var startPage: Int {
        let args = ProcessInfo.processInfo.arguments
        guard isOn, let i = args.firstIndex(of: "-page"), i + 1 < args.count else { return 0 }
        return Int(args[i + 1]) ?? 0
    }

    /// 12 hours of made-up readings, one a minute, ending a minute ago: a rise after
    /// breakfast, a dip in the afternoon, and a high after dinner that's falling now.
    static func seed() {
        let now = Date()
        let minutes = Int(GlucoseStore.historyHours * 60)
        let history: [GlucoseReading] = (0...minutes).reversed().map { back in
            let t = Double(minutes - back) / 60 // hours since the start
            var mgdl = 118 + 22 * sin(t / 1.3) + 9 * sin(t / 0.37 + 1)
            mgdl += 45 * exp(-pow((t - 3) / 0.8, 2))    // breakfast
            mgdl -= 45 * exp(-pow((t - 7) / 0.5, 2))    // dip
            mgdl += 65 * exp(-pow((t - 11) / 0.7, 2))   // dinner
            return GlucoseReading(mgdl: mgdl.rounded(), date: now.addingTimeInterval(-Double(back + 1) * 60), trend: .stable)
        }
        var readings = history
        for i in readings.indices where i >= 5 {
            let change = readings[i].mgdl - readings[i - 5].mgdl // per 5 min
            readings[i].trend = change <= -10 ? .fallingFast : change <= -5 ? .falling
                : change >= 10 ? .risingFast : change >= 5 ? .rising : .stable
        }
        GlucoseStore.snapshot = GlucoseSnapshot(current: readings.last!, history: readings, fetchedAt: now)
        GlucoseStore.steps = StepsSnapshot(count: 6_482, date: now)
    }
    #else
    static let isOn = false
    static let startPage = 0
    static func seed() {}
    #endif
}
