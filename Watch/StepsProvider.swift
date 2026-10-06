import Foundation
import HealthKit

/// Reads today's step count from HealthKit and caches it for the complications.
enum StepsProvider {
    private static let store = HKHealthStore()
    private static let stepType = HKQuantityType(.stepCount)

    static func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try? await store.requestAuthorization(toShare: [], read: [stepType])
    }

    /// Returns the cached value if HealthKit can't be read (e.g. the watch is locked).
    static func refresh() async -> StepsSnapshot? {
        guard HKHealthStore.isHealthDataAvailable() else { return GlucoseStore.steps }
        let now = Date()
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.startOfDay(for: now), end: nil)
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: stepType, predicate: predicate),
            options: .cumulativeSum)
        do {
            let statistics = try await descriptor.result(for: store)
            let count = Int(statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
            let snapshot = StepsSnapshot(count: count, date: now)
            GlucoseStore.steps = snapshot
            return snapshot
        } catch {
            return GlucoseStore.steps
        }
    }
}
