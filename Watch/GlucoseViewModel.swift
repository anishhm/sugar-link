import Foundation
import Observation
import WidgetKit

@Observable
@MainActor
final class GlucoseViewModel {
    private(set) var snapshot = GlucoseStore.snapshot
    private(set) var steps = GlucoseStore.steps
    /// Stored (not computed) so views redraw when a setting changes.
    var settings = GlucoseStore.settings {
        didSet {
            guard settings != oldValue else { return }
            GlucoseStore.settings = settings
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.glucose)
        }
    }
    private(set) var problem: FetchProblem?
    private(set) var isLoggedIn = CredentialStore.credentials != nil

    /// How often to fetch while the app is on screen. LibreLinkUp updates about once a minute.
    private let foregroundInterval: Duration = .seconds(60)
    /// Raising the wrist triggers a fetch; skip it if we fetched this recently.
    private let minimumFetchSpacing: TimeInterval = 20
    private var loop: Task<Void, Never>?
    /// The fetch in progress. It runs in its own task so leaving the app or
    /// restarting the loop never cancels it halfway; other callers wait for it.
    private var inFlight: Task<GlucoseSnapshot, Error>?

    var isRefreshing: Bool { inFlight != nil }

    init() {
        if DemoMode.isOn {
            DemoMode.seed()
            snapshot = GlucoseStore.snapshot
            steps = GlucoseStore.steps
            isLoggedIn = true
        }
    }

    /// Logs into LibreLinkUp directly from the watch.
    func logIn(email: String, password: String) async -> String? {
        let creds = LibreCredentials(email: email, password: password)
        let client = LibreLinkUpClient(credentials: creds, session: nil)
        do {
            let result = try await client.fetch()
            if creds.email != CredentialStore.credentials?.email {
                GlucoseStore.clear()
            }
            CredentialStore.credentials = creds
            CredentialStore.session = await client.session
            snapshot = GlucoseStore.store(current: result.current, graph: result.history)
            isLoggedIn = true
            problem = nil
            WidgetCenter.shared.reloadAllTimelines()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// Clears credentials and stored data when logging out.
    func logOut() {
        CredentialStore.credentials = nil
        CredentialStore.session = nil
        GlucoseStore.clear()
        snapshot = nil
        steps = nil
        problem = nil
        isLoggedIn = false
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Called whenever the app becomes active: opening it, or raising the wrist
    /// while it's the frontmost app. Fetches straight away, then once a minute.
    func start() {
        if loop == nil {
            loop = Task { [weak self] in
                while !Task.isCancelled {
                    await self?.refresh()
                    try? await Task.sleep(for: self?.foregroundInterval ?? .seconds(60))
                }
            }
        } else {
            Task { await refresh() }
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
    }

    /// `force` skips the spacing check (used when you tap the value).
    func refresh(force: Bool = false) async {
        guard !DemoMode.isOn else { return }
        reloadFromStore()
        guard isLoggedIn else { return }

        if let inFlight {
            _ = try? await inFlight.value
            reloadFromStore()
            return
        }
        if !force, let fetchedAt = snapshot?.fetchedAt,
           Date().timeIntervalSince(fetchedAt) < minimumFetchSpacing {
            return
        }

        let task = Task { try await GlucoseRefresher.refresh() }
        inFlight = task
        defer { inFlight = nil }

        // Reloads requested while the app is in the foreground don't use up the
        // complication budget, so the face is current whenever you leave the app.
        let previousDate = snapshot?.current.date
        do {
            snapshot = try await task.value
            problem = nil
        } catch {
            if let newProblem = FetchProblem(error) { problem = newProblem }
        }
        if snapshot?.current.date != previousDate {
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.glucose)
        }

        if settings.showSteps {
            let previousSteps = steps?.count(on: .now)
            if let newSteps = await StepsProvider.refresh() {
                steps = newSteps
                if newSteps.count != previousSteps {
                    WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.steps)
                }
            }
        }
    }

    private func reloadFromStore() {
        snapshot = GlucoseStore.snapshot
        steps = GlucoseStore.steps
        isLoggedIn = CredentialStore.credentials != nil
        if !isLoggedIn { problem = nil }
    }
}
