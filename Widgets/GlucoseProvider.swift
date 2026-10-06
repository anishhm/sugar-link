import WidgetKit

struct GlucoseEntry: TimelineEntry {
    let date: Date
    let snapshot: GlucoseSnapshot?
    let settings: DisplaySettings
    let isLoggedIn: Bool

    var isStale: Bool {
        snapshot?.isStale(at: date, after: settings.staleMinutes) ?? true
    }

    static let preview: GlucoseEntry = {
        let now = Date()
        let history = (0..<36).map { i in
            GlucoseReading(
                mgdl: 130 + 30 * sin(Double(i) / 6),
                date: now.addingTimeInterval(Double(i - 35) * 5 * 60),
                trend: .rising)
        }
        return GlucoseEntry(
            date: now,
            snapshot: GlucoseSnapshot(current: history.last!, history: history, fetchedAt: now),
            settings: DisplaySettings(),
            isLoggedIn: true)
    }()
}

struct GlucoseProvider: TimelineProvider {
    /// Ask WidgetKit to rebuild the timeline this often. watchOS rations reloads,
    /// so asking more often doesn't help; it only uses the budget up sooner.
    static let reloadInterval: TimeInterval = 5 * 60
    /// Every reload is precious, so fetch from LibreLinkUp unless the watch app
    /// or a background refresh fetched moments ago.
    static let fetchIfFetchedBefore: TimeInterval = 45

    func placeholder(in context: Context) -> GlucoseEntry { .preview }

    func getSnapshot(in context: Context, completion: @escaping (GlucoseEntry) -> Void) {
        completion(context.isPreview ? .preview : makeEntry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GlucoseEntry>) -> Void) {
        Task {
            let sinceFetch = GlucoseStore.snapshot.map { Date().timeIntervalSince($0.fetchedAt) } ?? .infinity
            if sinceFetch > Self.fetchIfFetchedBefore {
                _ = try? await GlucoseRefresher.refresh()
            }

            // One entry per minute so the age and stale coloring stay right
            // between reloads.
            let now = Date()
            let entries = (0..<30).map { makeEntry(at: now.addingTimeInterval(Double($0) * 60)) }
            completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(Self.reloadInterval))))
        }
    }

    private func makeEntry(at date: Date) -> GlucoseEntry {
        GlucoseEntry(
            date: date,
            snapshot: GlucoseStore.snapshot,
            settings: GlucoseStore.settings,
            isLoggedIn: CredentialStore.credentials != nil)
    }
}
