import AppKit
import SwiftUI

// The complications, drawn on the Mac for the README with the app's own chart code
// (Shared/) and the same sample day as the app's demo mode. The layouts copy
// Widgets/GlucoseComplication.swift and Widgets/StepsComplication.swift; the curved
// corner complication can only be drawn on a watch, so it isn't shown.
// Run from the project folder:
//   swiftc -parse-as-library Shared/*.swift scripts/complications.swift -o /tmp/compl && /tmp/compl

let now = Date()

/// Same sample day as Watch/DemoMode.swift.
let snapshot: GlucoseSnapshot = {
    let minutes = 12 * 60
    var readings: [GlucoseReading] = (0...minutes).reversed().map { back in
        let t = Double(minutes - back) / 60
        var mgdl = 118 + 22 * sin(t / 1.3) + 9 * sin(t / 0.37 + 1)
        mgdl += 45 * exp(-pow((t - 3) / 0.8, 2))
        mgdl -= 45 * exp(-pow((t - 7) / 0.5, 2))
        mgdl += 65 * exp(-pow((t - 11) / 0.7, 2))
        return GlucoseReading(mgdl: mgdl.rounded(), date: now.addingTimeInterval(-Double(back + 1) * 60), trend: .stable)
    }
    for i in readings.indices where i >= 5 {
        let change = readings[i].mgdl - readings[i - 5].mgdl
        readings[i].trend = change <= -10 ? .fallingFast : change <= -5 ? .falling
            : change >= 10 ? .risingFast : change >= 5 ? .rising : .stable
    }
    return GlucoseSnapshot(current: readings.last!, history: readings, fetchedAt: now)
}()
let settings = DisplaySettings()
let value = settings.format(snapshot.current.mgdl)
let arrow = snapshot.current.trend.arrow
let color = settings.color(for: snapshot.current, stale: false)
let recent = snapshot.sampled(every: 5, lastHours: 3, until: now)
let start = now.addingTimeInterval(-3 * 3600)

/// The watch's accessory background (a translucent disc).
struct Disc: View {
    var body: some View { Circle().fill(Color.white.opacity(0.14)) }
}

struct Rectangular: View {
    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: -2) {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(value).font(.system(size: 34, weight: .bold, design: .rounded))
                    Text(arrow).font(.system(size: 20, weight: .bold))
                }
                .foregroundStyle(color)
                Text("\(snapshot.delta.map(settings.formatDelta) ?? "") · 1m")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .fixedSize()
            GlucoseTargetBars(readings: recent, settings: settings, start: start, end: now)
        }
        .frame(width: 180, height: 64)
    }
}

struct GlucoseCircular: View {
    var body: some View {
        ZStack {
            Disc()
            GlucoseRing(readings: recent, settings: settings, start: start, end: now).padding(1.5)
            VStack(spacing: -3) {
                Text(value).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(color)
                Text(arrow).font(.system(size: 12, weight: .semibold))
            }
            .padding(8)
        }
        .frame(width: 50, height: 50)
    }
}

struct StepsCircular: View {
    var body: some View {
        ZStack {
            Disc()
            VStack(spacing: 0) {
                Image(systemName: "figure.walk").font(.system(size: 14, weight: .semibold))
                Text(StepsSnapshot.formatted(6_482, compact: true))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            .padding(3)
        }
        .frame(width: 50, height: 50)
    }
}

/// A Modular-style face: inline at the top, the rectangular complication in the
/// middle, round ones below. Same size as the app screenshots (208 × 248 points).
struct Face: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(value) \(arrow)").font(.system(size: 15, weight: .semibold, design: .rounded))
                Spacer()
                Text("10:09").font(.system(size: 30, weight: .semibold, design: .rounded))
            }
            Spacer(minLength: 0)
            Rectangular()
            Spacer(minLength: 0)
            HStack {
                GlucoseCircular()
                Spacer()
                StepsCircular()
                Spacer()
                GlucoseCircular().saturation(0).opacity(0) // empty slot keeps the spacing
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .frame(width: 208, height: 248)
        .foregroundStyle(.white)
        .background(Color.black)
        .environment(\.colorScheme, .dark)
    }
}

/// Each complication on its own, larger, with its name.
struct Parts: View {
    func item<V: View>(_ name: String, _ view: V) -> some View {
        VStack(spacing: 8) {
            view
            Text(name).font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(.gray)
        }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 22) {
            item("Rectangular", Rectangular())
            item("Circular", GlucoseCircular())
            item("Inline", Text("\(value) \(arrow)").font(.system(size: 15, weight: .semibold, design: .rounded)).frame(height: 50))
            item("Steps", StepsCircular())
        }
        .padding(20)
        .foregroundStyle(.white)
        .background(Color.black)
        .environment(\.colorScheme, .dark)
    }
}

@main
struct Render {
    @MainActor static func main() throws {
        for (view, name) in [(AnyView(Face()), "complications-face.png"), (AnyView(Parts()), "complications.png")] {
            let r = ImageRenderer(content: view)
            r.scale = 2
            let data = NSBitmapImageRep(cgImage: r.cgImage!).representation(using: .png, properties: [:])!
            try data.write(to: URL(fileURLWithPath: "docs/screenshots/" + name))
        }
    }
}
