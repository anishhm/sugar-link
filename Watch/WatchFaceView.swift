import SwiftUI

/// Three pages, scrolled with the Digital Crown:
/// 1. Now: glucose, trend in words, 3-hour graph, steps (graph and steps optional).
/// 2. Graph: 3 / 6 / 12 hours, bigger.
/// 3. Stats for the last 12 hours: time in range, average, lowest, highest.
/// When fetching fails, the last reading stays up with a calm note saying how old it is.
struct WatchFaceView: View {
    @Environment(GlucoseViewModel.self) private var model
    @Environment(\.isLuminanceReduced) private var isDimmed

    @State private var showSettings = false
    @State private var page = DemoMode.startPage

    var body: some View {
        if !model.isLoggedIn {
            WatchLoginView()
                .persistentSystemOverlays(.hidden)
        } else {
            NavigationStack {
                Group {
                    if let snapshot = model.snapshot {
                        TabView(selection: $page) {
                            NowPage(snapshot: snapshot).tag(0)
                            GraphPage(snapshot: snapshot, settings: model.settings).tag(1)
                            StatsPage(snapshot: snapshot, settings: model.settings).tag(2)
                        }
                        .tabViewStyle(.verticalPage)
                    } else if let problem = model.problem {
                        switch problem {
                        case .needsAction(let text): Message(symbol: problem.symbol, text: text)
                        case .offline: Message(symbol: problem.symbol, text: "No connection. Trying again in a minute.")
                        case .unavailable: Message(symbol: problem.symbol, text: "LibreLinkUp isn't answering. Trying again in a minute.")
                        }
                    } else {
                        ProgressView("Getting your reading…")
                    }
                }
                // watchOS places this in the top corner and keeps it there on every page.
                .toolbar {
                    if !isDimmed {
                        ToolbarItem(placement: .topBarLeading) {
                            // Plain and small so it doesn't compete with the reading.
                            Button { showSettings = true } label: {
                                Image(systemName: "gearshape")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Settings")
                        }
                    }
                }
                .sheet(isPresented: $showSettings) {
                    NavigationStack { WatchSettingsView() }
                }
            }
            .persistentSystemOverlays(.hidden)
        }
    }
}

// MARK: - Page 1: Now

private struct NowPage: View {
    @Environment(GlucoseViewModel.self) private var model
    @Environment(\.isLuminanceReduced) private var isDimmed
    let snapshot: GlucoseSnapshot

    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = context.date
            let settings = model.settings
            let stale = snapshot.isStale(at: now, after: settings.staleMinutes)
            VStack(spacing: 4) {
                GlucoseBlock(snapshot: snapshot, settings: settings, stale: stale, isDimmed: isDimmed)
                    .contentShape(Rectangle())
                    .onTapGesture { Task { await model.refresh(force: true) } }

                StatusLine(snapshot: snapshot, problem: model.problem, stale: stale, now: now, isDimmed: isDimmed)

                if settings.showChart {
                    GlucoseLineChart(
                        readings: snapshot.history(lastHours: 3, until: now),
                        settings: settings,
                        start: now.addingTimeInterval(-3 * 3600),
                        end: now,
                        isDimmed: isDimmed,
                        isStale: stale)
                        .opacity(isDimmed ? 0.6 : 1)
                        .frame(minHeight: 50, maxHeight: .infinity)
                        .padding(.horizontal, 6)
                } else {
                    Spacer(minLength: 0)
                }

                if settings.showSteps {
                    Label(StepsSnapshot.formatted(model.steps?.count(on: now) ?? 0), systemImage: "figure.walk")
                        .font(.system(.footnote, design: .rounded, weight: .medium))
                        .foregroundStyle(isDimmed ? .secondary : .primary)
                }
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct GlucoseBlock: View {
    let snapshot: GlucoseSnapshot
    let settings: DisplaySettings
    let stale: Bool
    let isDimmed: Bool

    var body: some View {
        let reading = snapshot.current
        let color = settings.color(for: reading, stale: stale)

        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(settings.format(reading.mgdl))
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .contentTransition(.numericText(value: reading.mgdl))
            if !stale {
                Text(reading.trend.arrow)
                    .font(.system(size: 36, weight: .bold))
            }
        }
        .foregroundStyle(isDimmed ? color.opacity(0.7) : color)
        .animation(.snappy, value: reading.mgdl)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(settings.format(reading.mgdl)) \(settings.unit.label), \(reading.trend.spokenName)")
    }
}

/// Normally "Falling · 1 min ago". When the reading is old or fetching fails:
/// an icon plus "Reading from 10:23", never raw error text.
private struct StatusLine: View {
    let snapshot: GlucoseSnapshot
    let problem: FetchProblem?
    let stale: Bool
    let now: Date
    let isDimmed: Bool

    var body: some View {
        let reading = snapshot.current
        let minutes = max(0, Int(now.timeIntervalSince(reading.date) / 60))
        let showsProblem = stale || (problem != nil && minutes >= 2)
        let age = minutes < 1 ? "just now" : "\(minutes) min ago"
        let trend = reading.trend.label

        VStack(spacing: 1) {
            if showsProblem {
                HStack(spacing: 4) {
                    Image(systemName: problem?.symbol ?? "clock")
                    Text("Reading from \(Text(reading.date, format: .dateTime.hour().minute()))")
                }
                if case .needsAction(let text) = problem, !isDimmed {
                    Text(text)
                        .font(.system(.caption2, design: .rounded))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
            } else {
                Text(trend.isEmpty ? age : "\(trend) · \(age)")
            }
        }
        .font(.system(.footnote, design: .rounded, weight: .medium))
        .foregroundStyle(.secondary)
    }
}

// MARK: - Page 2: Graph

private struct GraphPage: View {
    let snapshot: GlucoseSnapshot
    let settings: DisplaySettings
    @Environment(\.isLuminanceReduced) private var isDimmed
    @State private var hours: Double = 12

    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = context.date
            VStack(spacing: 6) {
                Text("Last \(Int(hours)) hours")
                    .font(.system(.footnote, design: .rounded, weight: .semibold))

                GlucoseLineChart(
                    readings: snapshot.history(lastHours: hours, until: now),
                    settings: settings,
                    start: now.addingTimeInterval(-hours * 3600),
                    end: now,
                    isDimmed: isDimmed,
                    isStale: snapshot.isStale(at: now, after: settings.staleMinutes),
                    lineWidth: 2.5)
                    .id(hours) // draws in again when you change the span
                    .frame(maxHeight: .infinity)
                    .padding(.horizontal, 6)

                HStack(spacing: 6) {
                    ForEach([3.0, 6.0, 12.0], id: \.self) { option in
                        Button("\(Int(option))h") {
                            withAnimation(.snappy) { hours = option }
                        }
                        .buttonStyle(.plain)
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(option == hours ? 0.3 : 0.1)))
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Page 3: Stats

private struct StatsPage: View {
    let snapshot: GlucoseSnapshot
    let settings: DisplaySettings
    @Environment(\.isLuminanceReduced) private var isDimmed

    var body: some View {
        TimelineView(.everyMinute) { context in
            if let stats = GlucoseStats(snapshot, settings: settings, lastHours: 12, until: context.date) {
                VStack(spacing: 6) {
                    Text("Last 12 hours")
                        .font(.system(.footnote, design: .rounded, weight: .semibold))

                    RangeBar(stats: stats)
                        .frame(height: 10)
                        .padding(.horizontal, 10)

                    VStack(spacing: 0) {
                        Text("\(Int((stats.share(.inRange) * 100).rounded()))% in range")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(GlucoseRange.inRange.color)
                        Text("\(settings.format(settings.low))–\(settings.format(settings.elevated)) \(settings.unit.label)")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 14) {
                        stat(stats.average, "average")
                        stat(stats.lowest, "lowest")
                        stat(stats.highest, "highest")
                    }
                }
                .opacity(isDimmed ? 0.7 : 1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Message(symbol: "chart.bar", text: "Not enough readings yet.")
            }
        }
    }

    private func stat(_ value: Double, _ label: String) -> some View {
        VStack(spacing: 0) {
            Text(settings.format(value))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(settings.range(of: value).color)
            Text(label)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}

/// Time in each range as one bar: red, green, orange, purple.
private struct RangeBar: View {
    let stats: GlucoseStats

    var body: some View {
        let ranges = [GlucoseRange.low, .inRange, .elevated, .high].filter { stats.share($0) > 0 }
        GeometryReader { geo in
            let spacing: CGFloat = 2
            let width = geo.size.width - spacing * CGFloat(max(0, ranges.count - 1))
            HStack(spacing: spacing) {
                ForEach(ranges, id: \.self) { range in
                    range.color.frame(width: max(2, width * stats.share(range)))
                }
            }
            .clipShape(Capsule())
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Shared

private struct Message: View {
    let symbol: String
    let text: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.title2)
            Text(text)
                .font(.footnote)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
