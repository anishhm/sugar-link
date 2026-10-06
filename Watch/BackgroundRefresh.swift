import WatchKit
import WidgetKit

/// Keeps the complications fresh while the app isn't on screen. watchOS decides
/// the actual timing: an app with a complication on the active face gets up to
/// four background refreshes an hour. These come on top of the complication's
/// own timeline reloads, which have a separate budget.
enum BackgroundRefresh {
    static let interval: TimeInterval = 15 * 60

    static func schedule() {
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: Date().addingTimeInterval(interval), userInfo: nil
        ) { error in
            if let error { print("Background refresh not scheduled: \(error.localizedDescription)") }
        }
    }

    static func run() async {
        let previousDate = GlucoseStore.snapshot?.current.date
        let snapshot = try? await GlucoseRefresher.refresh()
        if let snapshot, snapshot.current.date != previousDate {
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.glucose)
        }

        if GlucoseStore.settings.showSteps {
            let previousSteps = GlucoseStore.steps?.count(on: .now)
            if let steps = await StepsProvider.refresh(), steps.count != previousSteps {
                WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.steps)
            }
        }
        schedule()
    }
}
