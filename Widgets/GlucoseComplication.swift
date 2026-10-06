import SwiftUI
import WidgetKit

struct GlucoseComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.glucose, provider: GlucoseProvider()) { entry in
            GlucoseComplicationView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Glucose")
        .description("Your latest Libre 3 reading and trend.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline, .accessoryRectangular])
    }
}

struct GlucoseComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GlucoseEntry

    var body: some View {
        if let snapshot = entry.snapshot, entry.isLoggedIn {
            switch family {
            case .accessoryCorner: corner(snapshot)
            case .accessoryInline: inline(snapshot)
            case .accessoryRectangular: rectangular(snapshot)
            default: circular(snapshot)
            }
        } else {
            placeholder
        }
    }

    private var settings: DisplaySettings { entry.settings }

    private func value(_ snapshot: GlucoseSnapshot) -> String {
        settings.format(snapshot.current.mgdl)
    }

    private func arrow(_ snapshot: GlucoseSnapshot) -> String {
        entry.isStale ? "" : snapshot.current.trend.arrow
    }

    private func color(_ snapshot: GlucoseSnapshot) -> Color {
        settings.color(for: snapshot.current, stale: entry.isStale)
    }

    // MARK: - Families

    private func circular(_ snapshot: GlucoseSnapshot) -> some View {
        ZStack {
            AccessoryWidgetBackground()
            GlucoseRing(
                readings: snapshot.sampled(every: 5, lastHours: 3, until: entry.date),
                settings: settings,
                start: entry.date.addingTimeInterval(-3 * 3600),
                end: entry.date,
                isStale: entry.isStale)
                .padding(1.5)
            VStack(spacing: -3) {
                Text(value(snapshot))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(color(snapshot))
                    .widgetAccentable()
                if !entry.isStale {
                    Text(arrow(snapshot))
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            .padding(8)
        }
    }

    private func corner(_ snapshot: GlucoseSnapshot) -> some View {
        Text("\(value(snapshot))\(arrow(snapshot))")
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundStyle(color(snapshot))
            .widgetAccentable()
            .widgetCurvesContent()
            .widgetLabel {
                // The gauge spans your limits, so its end labels are true: below the
                // red limit sits at the start, above the purple limit at the end.
                let range = settings.low...settings.high
                Gauge(value: min(max(snapshot.current.mgdl, range.lowerBound), range.upperBound), in: range) {
                    Text(settings.unit.label)
                } currentValueLabel: {
                    EmptyView()
                } minimumValueLabel: {
                    Text(settings.format(settings.low))
                } maximumValueLabel: {
                    Text(settings.format(settings.high))
                }
                // A little wider than the gauge, so red and purple show as tips at the ends.
                .tint(settings.gaugeGradient(over: (settings.low - 12)...(settings.high + 12)))
            }
    }

    private func inline(_ snapshot: GlucoseSnapshot) -> some View {
        Text("\(value(snapshot)) \(arrow(snapshot))")
    }

    /// "−5 · 3m": change over 5 minutes and how old the reading is. Only the age when
    /// the reading is old (or there's no change to show).
    private func shortStatus(_ snapshot: GlucoseSnapshot) -> String {
        let minutes = max(0, Int(entry.date.timeIntervalSince(snapshot.current.date) / 60))
        let age = minutes < 1 ? "now" : "\(minutes)m"
        guard !entry.isStale, let delta = snapshot.delta else { return age }
        return "\(settings.formatDelta(delta)) · \(age)"
    }

    /// Number, arrow and short status on the left; bars fill the rest after a fixed gap.
    private func rectangular(_ snapshot: GlucoseSnapshot) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: -2) {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(value(snapshot))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(arrow(snapshot))
                        .font(.system(size: 20, weight: .bold))
                }
                .foregroundStyle(color(snapshot))
                .widgetAccentable()

                Text(shortStatus(snapshot))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .fixedSize()

            GlucoseTargetBars(
                readings: snapshot.sampled(every: 5, lastHours: 3, until: entry.date),
                settings: settings,
                start: entry.date.addingTimeInterval(-3 * 3600),
                end: entry.date)
                .opacity(entry.isStale ? 0.4 : 1)
        }
    }

    private var placeholder: some View {
        Group {
            switch family {
            case .accessoryInline:
                Text(entry.isLoggedIn ? "Sugar Link: --" : "Sugar Link: log in")
            case .accessoryRectangular:
                VStack(alignment: .leading) {
                    Text("--").font(.system(size: 30, weight: .bold, design: .rounded))
                    Text(entry.isLoggedIn ? "Waiting for reading" : "Open Sugar Link to log in")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            default:
                ZStack {
                    AccessoryWidgetBackground()
                    Text("--").font(.system(size: 20, weight: .bold, design: .rounded))
                }
            }
        }
    }
}

#Preview(as: .accessoryRectangular) {
    GlucoseComplication()
} timeline: {
    GlucoseEntry.preview
}
