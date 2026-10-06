// Round 2 idea sheets: graph labels, Digital Crown, subtext, number fonts (not part of the app).
// swiftc -parse-as-library design/mockups/render2.swift -o /tmp/render2 && /tmp/render2 design/mockups
import AppKit
import Charts
import SwiftUI

// MARK: - Data and colors (same 4 ranges as the app)

let low = 70.0, elevated = 150.0, high = 180.0
let red = Color(red: 1, green: 0.27, blue: 0.23)
let green = Color(red: 0.19, green: 0.82, blue: 0.35)
let orange = Color(red: 1, green: 0.62, blue: 0.04)
let purple = Color(red: 0.75, green: 0.35, blue: 0.95)
let bezel = Color(white: 0.22)
let faint = Color(white: 0.55)
func rangeColor(_ v: Double) -> Color { v < low ? red : v < elevated ? green : v <= high ? orange : purple }

struct P: Identifiable { let id: Int; let date: Date; let v: Double }
let now = Date(timeIntervalSince1970: Double(1_791_300_000 - 1_791_300_000 % 3600 + 2520)) // xx:42
let values: [Double] = [112, 115, 118, 124, 135, 150, 166, 182, 196, 205, 208, 203, 192, 176, 160, 145, 130, 116, 102,
                        90, 79, 70, 64, 61, 63, 68, 76, 86, 96, 108, 120, 132, 142, 148, 146, 141, 136]
func series(hours: Double) -> [P] {
    // Repeat the pattern backwards for longer windows.
    let count = Int(hours * 12) + 1
    return (0..<count).map { i in
        let back = count - 1 - i
        // Last 3 h: the sample values. Before that: a slow, smooth made-up day.
        let v: Double
        if back < values.count {
            v = values[values.count - 1 - back]
        } else {
            let t = Double(back - values.count + 1) / 12   // hours before the sample
            v = 112 + 45 * sin(t / 1.6) + 18 * sin(t / 0.55 + 1)
        }
        return P(id: i, date: now.addingTimeInterval(Double(-back) * 300), v: v)
    }
}
let data = series(hours: 3)
let start = data.first!.date

func gradient(_ pts: [P]) -> LinearGradient {
    let lo = pts.map(\.v).min()!, hi = pts.map(\.v).max()!
    func at(_ y: Double) -> Double { min(1, max(0, (y - lo) / (hi - lo))) }
    return LinearGradient(stops: [
        .init(color: red, location: 0), .init(color: red, location: at(low)),
        .init(color: green, location: at(low)), .init(color: green, location: at(elevated)),
        .init(color: orange, location: at(elevated)), .init(color: orange, location: at(high)),
        .init(color: purple, location: at(high)), .init(color: purple, location: 1),
    ], startPoint: .bottom, endPoint: .top)
}

let rounded = Font.system(size: 62, weight: .bold, design: .rounded)
func timeText(_ d: Date) -> String { d.formatted(.dateTime.hour().minute()) }

// MARK: - Building blocks

struct Watch<Content: View>: View {
    let title: String
    let note: String
    var recommended = false
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 6) {
            ZStack { content }
                .frame(width: 198, height: 242)
                .background(.black)
                .clipShape(RoundedRectangle(cornerRadius: 46, style: .continuous))
                .padding(7)
                .background(RoundedRectangle(cornerRadius: 52, style: .continuous).fill(bezel))
                .overlay(alignment: .trailing) { Crown() }
            HStack(spacing: 6) {
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                if recommended { Badge() }
            }
            Text(note).font(.system(size: 11)).foregroundStyle(Color(white: 0.65))
                .multilineTextAlignment(.center).frame(width: 220, height: 44, alignment: .top)
        }
    }
}

struct Crown: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 3).fill(Color(white: 0.35)).frame(width: 8, height: 34).offset(x: 5, y: -50)
    }
}

struct Badge: View {
    var body: some View {
        Text("Recommended").font(.system(size: 9, weight: .bold)).foregroundStyle(.black)
            .padding(.horizontal, 6).padding(.vertical, 2).background(Capsule().fill(green))
    }
}

struct Value: View {
    var text = "136"
    var arrow = "↘"
    var color = green
    var font = rounded
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(text).font(font).monospacedDigit()
            if !arrow.isEmpty { Text(arrow).font(.system(size: 34, weight: .bold)) }
        }.foregroundStyle(color)
    }
}

struct Sub: View {
    var text: String
    var body: some View {
        Text(text).font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(Color(white: 0.62))
    }
}

struct Steps: View {
    var body: some View {
        Label("6,214", systemImage: "figure.walk").font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(.white)
    }
}

struct CrownHint: View {
    var text: String
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "arrow.trianglehead.clockwise.rotate.90")
            Text(text)
        }
        .font(.system(size: 10, weight: .semibold)).foregroundStyle(.black)
        .padding(.horizontal, 7).padding(.vertical, 3).background(Capsule().fill(Color(white: 0.85)))
    }
}

struct Sheet<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title).font(.system(size: 26, weight: .bold)).foregroundStyle(.white)
            Text(subtitle).font(.system(size: 14)).foregroundStyle(Color(white: 0.7))
            content
        }
        .padding(30)
        .background(Color(red: 0.09, green: 0.09, blue: 0.1))
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - Graphs

func line(_ pts: [P], width: CGFloat = 3) -> some ChartContent {
    ForEach(pts) {
        LineMark(x: .value("t", $0.date), y: .value("v", $0.v))
            .interpolationMethod(.monotone).lineStyle(.init(lineWidth: width, lineCap: .round))
            .foregroundStyle(gradient(pts))
    }
}

func limitRules(labels: Bool) -> some ChartContent {
    ForEach([low, high], id: \.self) { y in
        RuleMark(y: .value("limit", y))
            .lineStyle(.init(lineWidth: 1, dash: [2, 3])).foregroundStyle(faint.opacity(0.6))
            .annotation(position: .top, alignment: .trailing, spacing: 1) {
                if labels { Text("\(Int(y))").font(.system(size: 9, weight: .semibold, design: .rounded)).foregroundStyle(faint) }
            }
    }
}

/// A: dashed limit lines labeled 70 / 180 on the right, hour ticks underneath.
struct GraphLimits: View {
    var pts = data
    var body: some View {
        Chart { limitRules(labels: true); line(pts) }
            .chartYScale(domain: 40...230)
            .chartXScale(domain: pts.first!.date...now)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour)) { _ in
                    AxisValueLabel(format: .dateTime.hour(), anchor: .top).font(.system(size: 9)).foregroundStyle(faint)
                }
            }
    }
}

/// B: highest and lowest value of the window labeled on the line, "3 h" caption.
struct GraphPeaks: View {
    var body: some View {
        let maxP = data.max { $0.v < $1.v }!, minP = data.min { $0.v < $1.v }!
        VStack(spacing: 2) {
            Chart {
                line(data)
                PointMark(x: .value("t", maxP.date), y: .value("v", maxP.v)).symbolSize(16).foregroundStyle(purple)
                    .annotation(position: .top, spacing: 1) { Text("208").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(purple) }
                PointMark(x: .value("t", minP.date), y: .value("v", minP.v)).symbolSize(16).foregroundStyle(red)
                    .annotation(position: .bottom, spacing: 1) { Text("61").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(red) }
            }
            .chartYScale(domain: 20...250).chartXScale(domain: start...now)
            .chartXAxis(.hidden).chartYAxis(.hidden)
            HStack { Text("3 h ago"); Spacer(); Text("now") }
                .font(.system(size: 9, weight: .medium)).foregroundStyle(faint)
        }
    }
}

/// C: both, kept light: limits on the right, peaks labeled, time span under it.
struct GraphBoth: View {
    var body: some View {
        let maxP = data.max { $0.v < $1.v }!, minP = data.min { $0.v < $1.v }!
        VStack(spacing: 2) {
            Chart {
                limitRules(labels: true)
                line(data)
                PointMark(x: .value("t", maxP.date), y: .value("v", maxP.v)).symbolSize(14).foregroundStyle(purple)
                    .annotation(position: .top, spacing: 1) { Text("208").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(purple) }
                PointMark(x: .value("t", minP.date), y: .value("v", minP.v)).symbolSize(14).foregroundStyle(red)
                    .annotation(position: .bottom, spacing: 1) { Text("61").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(red) }
            }
            .chartYScale(domain: 20...250).chartXScale(domain: start...now)
            .chartXAxis(.hidden).chartYAxis(.hidden)
            HStack { Text("3 h ago"); Spacer(); Text("now") }
                .font(.system(size: 9, weight: .medium)).foregroundStyle(faint).padding(.trailing, 18)
        }
    }
}

struct Screen<G: View>: View {
    var sub = "−5 in 5 min · 1 min ago"
    @ViewBuilder var graph: G
    var body: some View {
        VStack(spacing: 2) {
            Value()
            Sub(text: sub)
            graph.frame(maxHeight: .infinity).padding(.horizontal, 10).padding(.top, 6)
            Steps()
        }.padding(.top, 16).padding(.bottom, 14)
    }
}

// MARK: - Sheets

struct GraphSheet: View {
    var body: some View {
        Sheet(title: "1 · Making the graph readable",
              subtitle: "Today the graph shows the last 3 hours, but nothing says so. Three ways to label it without clutter.") {
            HStack(alignment: .top, spacing: 26) {
                Watch(title: "A · Limits + hours", note: "Dashed lines at 70 and 180 with labels; hour ticks under the line.") {
                    Screen { GraphLimits() }
                }
                Watch(title: "B · High & low", note: "Highest and lowest of the 3 h labeled; '3 h ago … now' underneath.") {
                    Screen { GraphPeaks() }
                }
                Watch(title: "C · Both, light", note: "Limits on the right, peaks labeled, time span below.", recommended: true) {
                    Screen { GraphBoth() }
                }
            }
        }
    }
}

struct CrownSheet: View {
    var body: some View {
        Sheet(title: "2 · What the Digital Crown could do",
              subtitle: "Pick one. (Combining them fights over the crown: it can't both scroll pages and scrub on the same screen.)") {
            Text("A · Scrub through time").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
            HStack(alignment: .top, spacing: 26) {
                Watch(title: "Turn the crown…", note: "A line moves back along the graph; the number shows that moment.") {
                    ScrubScreen(index: 10)
                }
                Watch(title: "…to any reading", note: "Let go: it springs back to now after 3 s.") {
                    ScrubScreen(index: 24)
                }
            }
            Text("B · Zoom the time span").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white).padding(.top, 6)
            HStack(alignment: .top, spacing: 26) {
                ForEach([(1.0, "1 h"), (3.0, "3 h"), (12.0, "12 h")], id: \.1) { hours, label in
                    Watch(title: label, note: "Crown steps 1 h → 3 h → 6 h → 12 h → 24 h.") {
                        VStack(spacing: 2) {
                            Value()
                            Sub(text: "−5 in 5 min · 1 min ago")
                            GraphLimits(pts: series(hours: hours)).frame(maxHeight: .infinity).padding(.horizontal, 10).padding(.top, 6)
                            CrownHint(text: label)
                        }.padding(.top, 16).padding(.bottom, 12)
                    }
                }
            }
            Text("C · Pages (scroll down)").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white).padding(.top, 6)
            HStack(alignment: .top, spacing: 26) {
                Watch(title: "Page 1 · Now", note: "Today's screen.", recommended: true) {
                    Screen { GraphBoth() }
                        .overlay(alignment: .trailing) { PageDots(selected: 0) }
                }
                Watch(title: "Page 2 · 12 hours", note: "Bigger graph with times and limits; tap 3 h / 6 h / 12 h.") {
                    PageGraph().overlay(alignment: .trailing) { PageDots(selected: 1) }
                }
                Watch(title: "Page 3 · Today", note: "Time in range, average, lowest / highest, steps.") {
                    PageStats().overlay(alignment: .trailing) { PageDots(selected: 2) }
                }
            }
        }
    }
}

struct ScrubScreen: View {
    let index: Int
    var body: some View {
        let p = data[index]
        VStack(spacing: 2) {
            Value(text: "\(Int(p.v))", arrow: "", color: rangeColor(p.v))
            Sub(text: "at \(timeText(p.date))")
            Chart {
                limitRules(labels: true)
                line(data)
                RuleMark(x: .value("t", p.date)).foregroundStyle(.white.opacity(0.8)).lineStyle(.init(lineWidth: 1.5))
                PointMark(x: .value("t", p.date), y: .value("v", p.v)).symbolSize(50).foregroundStyle(rangeColor(p.v))
            }
            .chartYScale(domain: 40...230).chartXScale(domain: start...now)
            .chartXAxis { AxisMarks(values: .stride(by: .hour)) { _ in AxisValueLabel(format: .dateTime.hour()).font(.system(size: 9)).foregroundStyle(faint) } }
            .chartYAxis(.hidden)
            .frame(maxHeight: .infinity).padding(.horizontal, 10).padding(.top, 6)
            CrownHint(text: "scrub")
        }.padding(.top, 16).padding(.bottom, 12)
    }
}

struct PageDots: View {
    let selected: Int
    var body: some View {
        VStack(spacing: 4) {
            ForEach(0..<3) { Circle().fill($0 == selected ? Color.white : Color(white: 0.35)).frame(width: 5, height: 5) }
        }.padding(.trailing, 5)
    }
}

struct PageGraph: View {
    var body: some View {
        let pts = series(hours: 12)
        VStack(spacing: 6) {
            Text("Last 12 hours").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
            Chart { limitRules(labels: true); line(pts, width: 2) }
                .chartYScale(domain: 40...230).chartXScale(domain: pts.first!.date...now)
                .chartXAxis { AxisMarks(values: .stride(by: .hour, count: 3)) { _ in
                    AxisGridLine().foregroundStyle(Color(white: 0.2))
                    AxisValueLabel(format: .dateTime.hour()).font(.system(size: 9)).foregroundStyle(faint) } }
                .chartYAxis(.hidden)
                .padding(.horizontal, 10)
            HStack(spacing: 6) {
                ForEach(["3h", "6h", "12h"], id: \.self) { s in
                    Text(s).font(.system(size: 11, weight: .semibold)).padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(s == "12h" ? Color(white: 0.32) : Color(white: 0.12)))
                }
            }.foregroundStyle(.white)
        }.padding(.vertical, 16)
    }
}

struct PageStats: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Today").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
            // Stacked time-in-range bar.
            GeometryReader { geo in
                HStack(spacing: 2) {
                    red.frame(width: geo.size.width * 0.08)
                    green.frame(width: geo.size.width * 0.62)
                    orange.frame(width: geo.size.width * 0.14)
                    purple.frame(width: geo.size.width * 0.16)
                }.clipShape(Capsule())
            }.frame(height: 10).padding(.horizontal, 22)
            Text("62% in range").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(green)
            Grid(horizontalSpacing: 18, verticalSpacing: 6) {
                GridRow { stat("128", "average"); stat("6,214", "steps") }
                GridRow { stat("61", "lowest", red); stat("208", "highest", purple) }
            }
        }.padding(.vertical, 16)
    }
    func stat(_ v: String, _ label: String, _ color: Color = .white) -> some View {
        VStack(spacing: 0) {
            Text(v).font(.system(size: 19, weight: .bold, design: .rounded)).foregroundStyle(color)
            Text(label).font(.system(size: 10)).foregroundStyle(faint)
        }
    }
}

struct TextSheet: View {
    var body: some View {
        Sheet(title: "3 · The line under the number   ·   4 · Number fonts",
              subtitle: "'−5 · now' doesn't say what −5 is. Options that explain themselves. Below: number styles (all free system fonts).") {
            HStack(alignment: .top, spacing: 26) {
                subOption("A · Say what it is", "Change over 5 min, then how fresh.", ["−5 in 5 min · 1 min ago"], recommended: true)
                subOption("B · Words", "Speed in words; age after.", ["Falling slowly · 1 min ago"])
                subOption("C · Two lines", "Trend on top, freshness below.", ["Falling · −5 in 5 min", "Updated 1 min ago"])
                subOption("D · Freshness only", "Arrow already shows direction.", ["Updated 1 min ago"])
            }
            Text("Number fonts").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white).padding(.top, 6)
            Grid(horizontalSpacing: 18, verticalSpacing: 18) {
                GridRow {
                    fontTile("1 · Rounded Bold (today)", Font.system(size: 64, weight: .bold, design: .rounded))
                    fontTile("2 · Rounded Black", Font.system(size: 64, weight: .black, design: .rounded))
                    fontTile("3 · Compressed Black", Font.system(size: 80, weight: .black).width(.compressed), recommended: true,
                             note: "Tall and punchy, like Apple's Modular faces")
                    fontTile("4 · Expanded Heavy", Font.system(size: 52, weight: .heavy).width(.expanded))
                }
                GridRow {
                    fontTile("5 · Monospaced Bold", Font.system(size: 58, weight: .bold, design: .monospaced))
                    fontTile("6 · New York serif", Font.system(size: 64, weight: .heavy, design: .serif))
                    fontTile("7 · Rounded + gradient", Font.system(size: 64, weight: .black, design: .rounded), style: .gradient,
                             note: "Fill fades within the range color")
                    fontTile("8 · Compressed + glow", Font.system(size: 80, weight: .black).width(.compressed), style: .glow,
                             note: "Soft glow in the range color")
                }
            }
        }
    }

    func subOption(_ title: String, _ note: String, _ lines: [String], recommended: Bool = false) -> some View {
        Watch(title: title, note: note, recommended: recommended) {
            VStack(spacing: 2) {
                Value()
                ForEach(lines, id: \.self) { Sub(text: $0) }
                GraphBoth().frame(maxHeight: .infinity).padding(.horizontal, 10).padding(.top, 6)
                Steps()
            }.padding(.top, 16).padding(.bottom, 14)
        }
    }

    enum Style { case plain, gradient, glow }

    func fontTile(_ title: String, _ font: Font, recommended: Bool = false, style: Style = .plain, note: String = "") -> some View {
        VStack(spacing: 6) {
            ZStack {
                switch style {
                case .plain:
                    Value(font: font)
                case .gradient:
                    Value(font: font).foregroundStyle(LinearGradient(colors: [Color(red: 0.55, green: 1, blue: 0.6), green, Color(red: 0.05, green: 0.6, blue: 0.3)], startPoint: .top, endPoint: .bottom))
                case .glow:
                    ZStack { Value(font: font).blur(radius: 8).opacity(0.8); Value(font: font) }
                }
            }
            .frame(width: 200, height: 110)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.black))
            HStack(spacing: 6) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                if recommended { Badge() }
            }
            Text(note).font(.system(size: 10.5)).foregroundStyle(Color(white: 0.65)).frame(height: 14)
        }
    }
}

// MARK: - Render

@main
struct Render {
    @MainActor static func main() throws {
        let dir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
        try save(GraphSheet(), to: "\(dir)/5-graph-labels.png")
        try save(CrownSheet(), to: "\(dir)/6-digital-crown.png")
        try save(TextSheet(), to: "\(dir)/7-subtext-and-fonts.png")
    }

    @MainActor static func save(_ view: some View, to path: String) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.cgImage,
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        else { throw CocoaError(.fileWriteUnknown) }
        try png.write(to: URL(fileURLWithPath: path))
        print("wrote \(path) \(image.width)x\(image.height)")
    }
}
