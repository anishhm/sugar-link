import Charts
import SwiftUI

/// Watch app graph: the line itself is colored by range, with a soft glow,
/// a draw-in when it appears, and a "now" dot that pulses faster the faster
/// glucose is changing. Dashed guides mark the green range (labeled), and hour
/// ticks underneath say which time span you're looking at.
struct GlucoseLineChart: View {
    let readings: [GlucoseReading]
    let settings: DisplaySettings
    let start: Date
    let end: Date
    var isDimmed = false
    var isStale = false
    var animateIn = true
    var lineWidth: CGFloat = 3

    @State private var reveal: CGFloat = 0

    var body: some View {
        let values = readings.map(\.mgdl)
        let lowest = values.min() ?? settings.low
        let highest = values.max() ?? settings.high
        let yDomain = min(40, lowest - 10)...max(settings.elevated + 50, highest + 10)
        let style = isStale
            ? AnyShapeStyle(Color.gray)
            : AnyShapeStyle(settings.lineGradient(lowest: lowest, highest: highest))
        let showFlair = !isDimmed && !isStale

        ZStack {
            guides(yDomain: yDomain)

            Group {
                if showFlair {
                    line(style, width: lineWidth, yDomain: yDomain).blur(radius: 4).opacity(0.7)
                }
                line(style, width: isDimmed ? lineWidth - 1 : lineWidth, yDomain: yDomain)
            }
            .mask(alignment: .leading) {
                GeometryReader { geo in Rectangle().frame(width: geo.size.width * reveal) }
            }

            if let last = readings.last {
                nowDot(last, yDomain: yDomain, animate: showFlair)
                    .opacity(reveal >= 1 ? 1 : 0)
            }
        }
        .onAppear {
            guard reveal < 1 else { return }
            if animateIn && !isDimmed {
                withAnimation(.easeOut(duration: 0.9)) { reveal = 1 }
            } else {
                reveal = 1
            }
        }
        .accessibilityHidden(true)
    }

    /// Still layer: dashed lines at the edges of the green range with their values,
    /// and the hour labels.
    private func guides(yDomain: ClosedRange<Double>) -> some View {
        Chart {
            ForEach([settings.low, settings.elevated], id: \.self) { limit in
                RuleMark(y: .value("Limit", limit))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    .foregroundStyle(Color.gray.opacity(isDimmed ? 0.35 : 0.55))
                    // Left end: the right end is where "now" and the newest data are.
                    .annotation(position: .top, alignment: .leading, spacing: 1) {
                        Text(settings.format(limit))
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.gray)
                    }
            }
        }
        .modifier(SharedScales(start: start, end: end, yDomain: yDomain, labelColor: .gray))
    }

    private func line(_ style: AnyShapeStyle, width: CGFloat, yDomain: ClosedRange<Double>) -> some View {
        Chart(readings, id: \.date) {
            LineMark(x: .value("Time", $0.date), y: .value("Glucose", $0.mgdl))
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
                .foregroundStyle(style)
        }
        .modifier(SharedScales(start: start, end: end, yDomain: yDomain, labelColor: .clear))
    }

    /// An invisible chart with the same scales, used only to place the dot exactly
    /// on the last reading.
    private func nowDot(_ reading: GlucoseReading, yDomain: ClosedRange<Double>, animate: Bool) -> some View {
        Chart {
            PointMark(x: .value("Time", reading.date), y: .value("Glucose", reading.mgdl))
                .opacity(0)
        }
        .modifier(SharedScales(start: start, end: end, yDomain: yDomain, labelColor: .clear))
        .chartOverlay { proxy in
            GeometryReader { geo in
                if let plotFrame = proxy.plotFrame,
                   let point = proxy.position(for: (x: reading.date, y: reading.mgdl)) {
                    let origin = geo[plotFrame].origin
                    NowDot(
                        color: isStale ? .gray : settings.range(of: reading.mgdl).color,
                        animate: animate,
                        period: Self.pulsePeriod(reading.trend))
                        .id(animate)
                        .position(x: origin.x + point.x, y: origin.y + point.y)
                }
            }
        }
    }

    static func pulsePeriod(_ trend: Trend) -> Double {
        switch trend {
        case .risingFast, .fallingFast: 0.8
        case .rising, .falling: 1.3
        case .stable, .unknown: 2.0
        }
    }
}

/// Same scales and hour axis on every layer of `GlucoseLineChart`, so they line up
/// exactly. Only the guides layer shows the hour labels; the others reserve the
/// same space with clear labels.
private struct SharedScales: ViewModifier {
    let start: Date
    let end: Date
    let yDomain: ClosedRange<Double>
    let labelColor: Color

    func body(content: Content) -> some View {
        let hours = end.timeIntervalSince(start) / 3600
        let stride = hours <= 3.5 ? 1 : hours <= 6.5 ? 2 : 3
        content
            .chartXScale(domain: start...end)
            .chartYScale(domain: yDomain)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: stride)) { _ in
                    AxisValueLabel(format: .dateTime.hour(), collisionResolution: .greedy)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(labelColor)
                }
            }
    }
}

private struct NowDot: View {
    let color: Color
    let animate: Bool
    let period: Double
    @State private var pulse = false

    var body: some View {
        ZStack {
            if animate {
                Circle()
                    .stroke(color, lineWidth: 2)
                    .frame(width: 10, height: 10)
                    .scaleEffect(pulse ? 2.6 : 1)
                    .opacity(pulse ? 0 : 0.8)
            }
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
                .overlay(Circle().stroke(.black, lineWidth: 2))
        }
        .onAppear {
            guard animate else { return }
            withAnimation(.easeOut(duration: period).repeatForever(autoreverses: false)) { pulse = true }
        }
    }
}

/// Small complication ring: the last few hours drawn around the value like a clock,
/// one segment per 5 minutes in its range color. Newest ends at 12 o'clock and is
/// brightest; older segments fade. Gaps in the data stay empty.
struct GlucoseRing: View {
    let readings: [GlucoseReading]
    let settings: DisplaySettings
    let start: Date
    let end: Date
    var lineWidth: CGFloat = 4.5
    var isStale = false

    var body: some View {
        Canvas { context, size in
            let radius = min(size.width, size.height) / 2 - lineWidth / 2
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let span = end.timeIntervalSince(start)
            guard span > 0 else { return }
            let segment = 300 / span // 5 minutes as a fraction of the ring
            let gap = 0.004          // small space between segments
            for reading in readings {
                let fraction = reading.date.timeIntervalSince(start) / span
                guard fraction > 0, fraction <= 1 else { continue }
                var path = Path()
                path.addArc(
                    center: center, radius: radius,
                    startAngle: .degrees(-90 + (fraction - segment + gap) * 360),
                    endAngle: .degrees(-90 + (fraction - gap) * 360),
                    clockwise: false)
                let color = isStale ? Color.gray : settings.range(of: reading.mgdl).color
                context.stroke(path, with: .color(color.opacity(0.25 + 0.75 * fraction)),
                               style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
            }
        }
        .accessibilityHidden(true)
    }
}

/// Complication graph: bars grow up or down from the middle of the green range,
/// colored by range. Pass evenly spaced readings (`GlucoseSnapshot.sampled`).
struct GlucoseTargetBars: View {
    let readings: [GlucoseReading]
    let settings: DisplaySettings
    let start: Date
    let end: Date
    var barWidth: CGFloat = 2

    var body: some View {
        let target = settings.target

        Chart {
            RuleMark(y: .value("Target", target))
                .lineStyle(StrokeStyle(lineWidth: 1))
                .foregroundStyle(Color.gray.opacity(0.6))
            ForEach(readings, id: \.date) { reading in
                BarMark(
                    x: .value("Time", reading.date),
                    yStart: .value("Target", target),
                    yEnd: .value("Glucose", Self.visibleEnd(reading.mgdl, target: target)),
                    width: .fixed(barWidth))
                    .foregroundStyle(settings.range(of: reading.mgdl).color)
            }
        }
        // Half a bar of room at each end, so the oldest and newest bars aren't clipped.
        .chartXScale(domain: start...end, range: .plotDimension(padding: barWidth / 2))
        .chartYScale(domain: Self.yDomain(readings.map(\.mgdl), target: target))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .accessibilityHidden(true)
    }

    /// Fits the bars, not a fixed window around the target: if every value is above
    /// the target, the target line sits at the bottom and the bars use the full
    /// height (and the other way round when all are below). At least 40 mg/dL tall,
    /// so small wiggles don't look like big swings.
    static func yDomain(_ values: [Double], target: Double, minimumSpan: Double = 40) -> ClosedRange<Double> {
        var lower = min(target, values.min() ?? target)
        var upper = max(target, values.max() ?? target)
        if upper - lower < minimumSpan {
            if lower >= target {
                upper = lower + minimumSpan          // all above: grow upwards
            } else if upper <= target {
                lower = upper - minimumSpan          // all below: grow downwards
            } else {
                let extra = (minimumSpan - (upper - lower)) / 2
                lower -= extra
                upper += extra
            }
        }
        let margin = (upper - lower) * 0.05
        return (lower - margin)...(upper + margin)
    }

    /// Keeps bars right at the target from disappearing.
    static func visibleEnd(_ value: Double, target: Double) -> Double {
        abs(value - target) >= 3 ? value : target + (value >= target ? 3 : -3)
    }
}
