import Foundation

/// Complication kinds, so each one is only reloaded when its own data changed
/// (every reload counts against watchOS's refresh budget).
enum WidgetKind {
    static let glucose = "Glucose"
    static let steps = "Steps"
}

/// Data shared through the App Group between the watch app and its complications.
enum GlucoseStore {
    static let historyHours: Double = 12

    static var defaults: UserDefaults {
        let group = Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String
        return group.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    static var snapshot: GlucoseSnapshot? {
        get { load(GlucoseSnapshot.self, "snapshot") }
        set { save(newValue, "snapshot") }
    }

    static var settings: DisplaySettings {
        get { load(DisplaySettings.self, "settings") ?? DisplaySettings() }
        set { save(newValue, "settings") }
    }

    static var steps: StepsSnapshot? {
        get { load(StepsSnapshot.self, "steps") }
        set { save(newValue, "steps") }
    }

    static var lastError: String? {
        get { defaults.string(forKey: "lastError") }
        set { defaults.set(newValue, forKey: "lastError") }
    }

    /// Merges a fresh fetch into the stored history. LibreLinkUp's graph only has
    /// a point every 15 minutes, so we also keep every "current" reading we've seen.
    @discardableResult
    static func store(current: GlucoseReading, graph: [GlucoseReading], at now: Date = .now) -> GlucoseSnapshot {
        let cutoff = now.addingTimeInterval(-historyHours * 3600)
        var byMinute: [Int: GlucoseReading] = [:]
        for reading in (snapshot?.history ?? []) + graph + [current] where reading.date >= cutoff {
            byMinute[Int(reading.date.timeIntervalSince1970 / 60)] = reading
        }
        let history = byMinute.values.sorted { $0.date < $1.date }
        let result = GlucoseSnapshot(current: current, history: history, fetchedAt: now)
        snapshot = result
        lastError = nil
        return result
    }

    static func clear() {
        snapshot = nil
        steps = nil
        lastError = nil
    }

    private static func load<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }

    private static func save<T: Encodable>(_ value: T?, _ key: String) {
        defaults.set(value.flatMap { try? JSONEncoder().encode($0) }, forKey: key)
    }
}

enum GlucoseRefresher {
    /// Fetches from LibreLinkUp with the stored login and saves the result.
    static func refresh() async throws -> GlucoseSnapshot {
        guard let credentials = CredentialStore.credentials else {
            throw LibreLinkUpError.notLoggedIn
        }
        let client = LibreLinkUpClient(credentials: credentials, session: CredentialStore.session)
        do {
            let result = try await client.fetch()
            CredentialStore.session = await client.session
            return GlucoseStore.store(current: result.current, graph: result.history)
        } catch {
            CredentialStore.session = await client.session
            if FetchProblem(error) != nil {
                GlucoseStore.lastError = error.localizedDescription
            }
            throw error
        }
    }
}
