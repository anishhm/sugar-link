import SwiftUI
import WidgetKit

struct StepsEntry: TimelineEntry {
    let date: Date
    let count: Int
}

/// Shows the step count cached by the watch app (it refreshes it with the glucose).
struct StepsTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> StepsEntry { StepsEntry(date: .now, count: 6214) }

    func getSnapshot(in context: Context, completion: @escaping (StepsEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StepsEntry>) -> Void) {
        let now = Date()
        var entries = [entry(at: now)]
        // Reset to 0 at midnight even if the app hasn't run yet.
        let midnight = Calendar.current.startOfDay(for: now.addingTimeInterval(86_400))
        if midnight.timeIntervalSince(now) < 3600 {
            entries.append(StepsEntry(date: midnight, count: 0))
        }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(15 * 60))))
    }

    private func entry(at date: Date) -> StepsEntry {
        StepsEntry(date: date, count: GlucoseStore.steps?.count(on: date) ?? 0)
    }
}

struct StepsComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.steps, provider: StepsTimelineProvider()) { entry in
            StepsComplicationView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Steps")
        .description("Today's step count.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline])
    }
}

struct StepsComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StepsEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            Label(StepsSnapshot.formatted(entry.count), systemImage: "figure.walk")
        case .accessoryCorner:
            Image(systemName: "figure.walk")
                .font(.system(size: 20, weight: .semibold))
                .widgetAccentable()
                .widgetLabel(StepsSnapshot.formatted(entry.count))
        default:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 14, weight: .semibold))
                        .widgetAccentable()
                    Text(StepsSnapshot.formatted(entry.count, compact: true))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
                .padding(3)
            }
        }
    }
}
