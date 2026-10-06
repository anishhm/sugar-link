import AppKit
import SwiftUI

// Icon + name options, drawn as watchOS shows them: circular, on black.
// Run from design/mockups: swiftc -parse-as-library icon_options.swift -o /tmp/icons && /tmp/icons

let red = Color(red: 1.0, green: 0.27, blue: 0.23)
let green = Color(red: 0.19, green: 0.82, blue: 0.35)
let orange = Color(red: 1.0, green: 0.62, blue: 0.04)
let purple = Color(red: 0.69, green: 0.32, blue: 0.87)
let ink = Color(red: 0.07, green: 0.08, blue: 0.11)

/// A smooth glucose-like curve across the width.
struct Wave: Shape {
    var points: [CGFloat] // y as fraction of height
    func path(in r: CGRect) -> Path {
        var p = Path()
        let pts = points.enumerated().map { CGPoint(x: r.minX + r.width * CGFloat($0.offset) / CGFloat(points.count - 1),
                                                    y: r.minY + r.height * $0.element) }
        p.move(to: pts[0])
        for i in 1..<pts.count {
            let a = pts[i - 1], b = pts[i]
            let mid = (a.x + b.x) / 2
            p.addCurve(to: b, control1: CGPoint(x: mid, y: a.y), control2: CGPoint(x: mid, y: b.y))
        }
        return p
    }
}

/// A — Tide: the day's line rising and falling, ending on today's dot.
struct TideIcon: View {
    var body: some View {
        GeometryReader { g in
            let s = g.size.width
            ZStack {
                LinearGradient(colors: [Color(red: 0.10, green: 0.16, blue: 0.22), ink], startPoint: .top, endPoint: .bottom)
                Wave(points: [0.62, 0.48, 0.56, 0.40, 0.50])
                    .stroke(green, style: StrokeStyle(lineWidth: s * 0.075, lineCap: .round))
                    .frame(width: s * 0.62, height: s * 0.5)
                    .offset(x: -s * 0.04)
                Circle().fill(.white)
                    .frame(width: s * 0.16)
                    .shadow(color: green, radius: s * 0.05)
                    .offset(x: s * 0.27, y: 0)
            }
        }
    }
}

/// B — Glint: just the glowing "now" dot from the app, with a short trail.
struct GlintIcon: View {
    var body: some View {
        GeometryReader { g in
            let s = g.size.width
            ZStack {
                ink
                Circle().fill(RadialGradient(colors: [green.opacity(0.55), .clear], center: .center, startRadius: 0, endRadius: s * 0.42))
                Wave(points: [0.95, 0.75, 0.5])
                    .stroke(LinearGradient(colors: [.clear, green.opacity(0.8)], startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: s * 0.06, lineCap: .round))
                    .frame(width: s * 0.36, height: s * 0.24)
                    .offset(x: -s * 0.17, y: s * 0.06)
                Circle().fill(.white).frame(width: s * 0.26)
                    .overlay(Circle().fill(green).frame(width: s * 0.18))
            }
        }
    }
}

/// C — Ring: the four ranges as one ring (mostly green), like the small complication.
struct RingIcon: View {
    var body: some View {
        GeometryReader { g in
            let s = g.size.width
            let segs: [(Color, CGFloat, CGFloat)] = [(red, 0.0, 0.10), (green, 0.12, 0.70), (orange, 0.72, 0.84), (purple, 0.86, 0.96)]
            ZStack {
                ink
                ForEach(0..<segs.count, id: \.self) { i in
                    Circle().trim(from: segs[i].1, to: segs[i].2)
                        .stroke(segs[i].0, style: StrokeStyle(lineWidth: s * 0.1, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: s * 0.6)
                }
                Circle().fill(.white).frame(width: s * 0.12)
            }
        }
    }
}

/// D — Steady: the green band with the line staying inside it.
struct BandIcon: View {
    var body: some View {
        GeometryReader { g in
            let s = g.size.width
            ZStack {
                ink
                RoundedRectangle(cornerRadius: s * 0.06).fill(green.opacity(0.22))
                    .frame(width: s, height: s * 0.34)
                Rectangle().fill(green.opacity(0.6)).frame(width: s, height: s * 0.012).offset(y: -s * 0.17)
                Rectangle().fill(green.opacity(0.6)).frame(width: s, height: s * 0.012).offset(y: s * 0.17)
                Wave(points: [0.75, 0.25, 0.6, 0.3, 0.5])
                    .stroke(.white, style: StrokeStyle(lineWidth: s * 0.06, lineCap: .round, lineJoin: .round))
                    .frame(width: s * 0.64, height: s * 0.26)
            }
        }
    }
}

/// E — Arrow: the trend arrow as the mark, in green on a soft disc.
struct ArrowIcon: View {
    var body: some View {
        GeometryReader { g in
            let s = g.size.width
            ZStack {
                LinearGradient(colors: [green, Color(red: 0.08, green: 0.55, blue: 0.30)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "arrow.forward")
                    .font(.system(size: s * 0.42, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(-30))
            }
        }
    }
}

/// F — Drop, redone: a flat, simple drop with a wave inside. Reads well when tiny.
struct DropIcon: View {
    var body: some View {
        GeometryReader { g in
            let s = g.size.width
            ZStack {
                ink
                Image(systemName: "drop.fill")
                    .font(.system(size: s * 0.56))
                    .foregroundStyle(LinearGradient(colors: [green, Color(red: 0.10, green: 0.62, blue: 0.40)], startPoint: .top, endPoint: .bottom))
                Wave(points: [0.6, 0.35, 0.55, 0.4])
                    .stroke(.white, style: StrokeStyle(lineWidth: s * 0.035, lineCap: .round))
                    .frame(width: s * 0.26, height: s * 0.12)
                    .offset(y: s * 0.07)
            }
        }
    }
}

struct Option: View {
    let letter: String
    let icon: AnyView
    let names: String
    let idea: String
    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .bottom, spacing: 18) {
                icon.frame(width: 190, height: 190).clipShape(Circle())
                icon.frame(width: 44, height: 44).clipShape(Circle()) // real size on the watch
            }
            Text("\(letter)  \(names)").font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(.white)
            Text(idea).font(.system(size: 14, design: .rounded)).foregroundStyle(.gray)
                .multilineTextAlignment(.center).frame(width: 300)
        }
        .frame(width: 330)
    }
}

struct Sheet: View {
    var body: some View {
        VStack(spacing: 36) {
            HStack(alignment: .top, spacing: 20) {
                Option(letter: "A", icon: AnyView(TideIcon()), names: "Tide", idea: "Your levels rise and fall like a tide. Line ends on today's dot.")
                Option(letter: "B", icon: AnyView(GlintIcon()), names: "Glint", idea: "Glance + glint: the glowing \"now\" dot from the app.")
                Option(letter: "C", icon: AnyView(RingIcon()), names: "Orbit", idea: "All four ranges in one ring, like the small complication.")
            }
            HStack(alignment: .top, spacing: 20) {
                Option(letter: "D", icon: AnyView(BandIcon()), names: "Steady", idea: "The line staying inside the green band: the goal.")
                Option(letter: "E", icon: AnyView(ArrowIcon()), names: "Drift", idea: "The trend arrow is what you check most. Bold and simple.")
                Option(letter: "F", icon: AnyView(DropIcon()), names: "Sugar", idea: "Keep the name; a cleaner drop that still reads at 44 px.")
            }
        }
        .padding(40)
        .background(Color.black)
    }
}

@main
struct Render {
    @MainActor static func main() throws {
        let r = ImageRenderer(content: Sheet())
        r.scale = 1
        let rep = NSBitmapImageRep(cgImage: r.cgImage!)
        try rep.representation(using: .png, properties: [:])!
            .write(to: URL(fileURLWithPath: "11-icon-name-options.png"))
    }
}
