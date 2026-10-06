import Foundation

enum GlucoseUnit: String, Codable, CaseIterable, Sendable, Identifiable {
    case mgdl
    case mmol

    var id: String { rawValue }

    var label: String {
        switch self {
        case .mgdl: "mg/dL"
        case .mmol: "mmol/L"
        }
    }
}

/// Red below `low`, green up to `elevated`, orange up to `high`, purple above.
enum GlucoseRange: Sendable {
    case low, inRange, elevated, high
}

/// Display settings, edited on the watch.
/// Thresholds are always stored in mg/dL.
struct DisplaySettings: Codable, Equatable, Sendable {
    static let mmolFactor = 18.0182

    var unit: GlucoseUnit = .mgdl
    var low: Double = 70
    var elevated: Double = 150
    var high: Double = 180
    var staleMinutes: Int = 15
    var showChart = true
    var showSteps = true

    func range(of mgdl: Double) -> GlucoseRange {
        if mgdl < low { return .low }
        if mgdl < elevated { return .inRange }
        if mgdl <= high { return .elevated }
        return .high
    }

    /// Middle of the green range; the complication's bars grow up or down from here.
    var target: Double { (low + elevated) / 2 }

    func format(_ mgdl: Double) -> String {
        switch unit {
        case .mgdl: String(Int(mgdl.rounded()))
        case .mmol: String(format: "%.1f", mgdl / Self.mmolFactor)
        }
    }

    func formatDelta(_ mgdl: Double) -> String {
        let magnitude = abs(mgdl)
        let text = switch unit {
        case .mgdl: String(Int(magnitude.rounded()))
        case .mmol: String(format: "%.1f", magnitude / Self.mmolFactor)
        }
        if Double(text) == 0 { return "±" + text }
        return (mgdl >= 0 ? "+" : "−") + text
    }
}

extension DisplaySettings {
    /// Tolerates settings saved by older versions (missing keys get defaults).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = DisplaySettings()
        unit = try c.decodeIfPresent(GlucoseUnit.self, forKey: .unit) ?? d.unit
        low = try c.decodeIfPresent(Double.self, forKey: .low) ?? d.low
        high = try c.decodeIfPresent(Double.self, forKey: .high) ?? d.high
        if let elevated = try c.decodeIfPresent(Double.self, forKey: .elevated) {
            self.elevated = elevated
        } else if high < d.high {
            // Saved before there were 4 colors: the old "High above" limit was where
            // orange started. Keep it as "Orange from" and start purple at 180.
            elevated = high
            high = d.high
        } else {
            elevated = d.elevated
        }
        staleMinutes = try c.decodeIfPresent(Int.self, forKey: .staleMinutes) ?? d.staleMinutes
        showChart = try c.decodeIfPresent(Bool.self, forKey: .showChart) ?? d.showChart
        showSteps = try c.decodeIfPresent(Bool.self, forKey: .showSteps) ?? d.showSteps
    }
}
