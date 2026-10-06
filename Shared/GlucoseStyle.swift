import SwiftUI

extension GlucoseRange {
    var color: Color {
        switch self {
        case .low: .red
        case .inRange: .green
        case .elevated: .orange
        case .high: .purple
        }
    }
}

extension DisplaySettings {
    func color(for reading: GlucoseReading, stale: Bool) -> Color {
        stale ? .gray : range(of: reading.mgdl).color
    }

    /// Vertical gradient that switches color exactly at the range limits.
    /// Swift Charts stretches a series' gradient over the series' own lowest...highest
    /// value, so pass those in.
    func lineGradient(lowest: Double, highest: Double) -> LinearGradient {
        guard highest - lowest > 0.5 else {
            let color = range(of: highest).color
            return LinearGradient(colors: [color, color], startPoint: .bottom, endPoint: .top)
        }
        func at(_ y: Double) -> Double { min(1, max(0, (y - lowest) / (highest - lowest))) }
        return LinearGradient(stops: [
            .init(color: GlucoseRange.low.color, location: 0),
            .init(color: GlucoseRange.low.color, location: at(low)),
            .init(color: GlucoseRange.inRange.color, location: at(low)),
            .init(color: GlucoseRange.inRange.color, location: at(elevated)),
            .init(color: GlucoseRange.elevated.color, location: at(elevated)),
            .init(color: GlucoseRange.elevated.color, location: at(high)),
            .init(color: GlucoseRange.high.color, location: at(high)),
            .init(color: GlucoseRange.high.color, location: 1),
        ], startPoint: .bottom, endPoint: .top)
    }

    /// For gauges: the four range colors, spaced over `range`.
    func gaugeGradient(over range: ClosedRange<Double>) -> Gradient {
        func at(_ y: Double) -> Double { min(1, max(0, (y - range.lowerBound) / (range.upperBound - range.lowerBound))) }
        return Gradient(stops: [
            .init(color: GlucoseRange.low.color, location: at(low)),
            .init(color: GlucoseRange.inRange.color, location: at(low)),
            .init(color: GlucoseRange.inRange.color, location: at(elevated)),
            .init(color: GlucoseRange.elevated.color, location: at(elevated)),
            .init(color: GlucoseRange.elevated.color, location: at(high)),
            .init(color: GlucoseRange.high.color, location: at(high)),
        ])
    }
}

extension StepsSnapshot {
    static func formatted(_ count: Int, compact: Bool = false) -> String {
        if compact && count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000)
        }
        return count.formatted(.number)
    }
}
