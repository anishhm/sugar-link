import SwiftUI

@main
struct SugarLinkWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = GlucoseViewModel()

    var body: some Scene {
        WindowGroup {
            WatchFaceView()
                .environment(model)
                .task { await StepsProvider.requestAuthorization() }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .active:
                model.start()
            case .background:
                model.stop()
                BackgroundRefresh.schedule()
            default:
                break
            }
        }
        .backgroundTask(.appRefresh) { _ in
            await BackgroundRefresh.run()
        }
    }
}
