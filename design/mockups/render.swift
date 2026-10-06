// Renders UI idea sheets with real SwiftUI + Swift Charts (not part of the app).
// swiftc -parse-as-library design/mockups/render.swift -o /tmp/render && /tmp/render design/mockups
import AppKit
import Charts
import SwiftUI

// MARK: - Sample data: 3 hours, a meal spike above range, a dip below, recovering.

let low = 70.0, high = 180.0, target = 120.0
let red = Color(red: 1, green: 0.27, blue: 0.23)
let green = Color(red: 0.19, green: 0.82, blue: 0.35)
let orange = Color(red: 1, green: 0.62, blue: 0.04)
let bezel = Color(white: 0.22)
func rangeColor(_ v: Double) -> Color { v < low ? red : v > high ? orange : green }

struct Point: Identifiable { let id: Int; let date: Date; let v: Double }
let now = Date(timeIntervalSince1970: 1_791_300_000)
let values: [Double] = [112, 115, 118, 124, 135, 150, 168, 186, 201, 212, 218, 214, 205, 192, 176, 160, 145, 130,
                        116, 102, 90, 79, 70, 64, 61, 63, 68, 76, 86, 96, 105, 112, 118, 123, 127, 131, 134]
let data = values.enumerated().map {
    Point(id: $0.offset, date: now.addingTimeInterval(Double($0.offset - values.count + 1) * 300), v: $0.element)
}
let start = data.first!.date
let forecast: [Point] = (0...4).map { i in
    Point(id: 100 + i, date: now.addingTimeInterval(Double(i) * 300), v: 134 + Double(i) * 3.5)
}
let yDomain = 40.0...240.0
let dataMin = values.min()!, dataMax = values.max()!

/// Vertical gradient whose color changes exactly at the low/high limits.
/// Swift Charts stretches a series' gradient over the series' own min...max.
func rangeGradient(from lo: Double = dataMin, to hi: Double = dataMax, soft: Double = 0) -> LinearGradient {
    func at(_ y: Double) -> Double { min(1, max(0, (y - lo) / (hi - lo))) }
    return LinearGradient(stops: [
        .init(color: red, location: 0), .init(color: red, location: at(low - soft)),
        .init(color: green, location: at(low + soft)), .init(color: green, location: at(high - soft)),
        .init(color: orange, location: at(high + soft)), .init(color: orange, location: 1),
    ], startPoint: .bottom, endPoint: .top)
}

// MARK: - Graph variants

struct GraphVariant { let name: String; let note: String }
let graphVariants: [GraphVariant] = [
    .init(name: "1 · Range-colored line", note: "Line itself turns red / green / orange at your limits. No band."),
    .init(name: "2 · Soft gradient line", note: "Same idea, colors blend near the limits."),
    .init(name: "3 · Dots", note: "One dot per reading, colored by range (like the Libre app)."),
    .init(name: "4 · Glow area", note: "Colored line with a faded colored fill underneath."),
    .init(name: "5 · 15-min bars", note: "Average per 15 min as rounded bars."),
    .init(name: "6 · Line + dashed limits", note: "Colored line, thin dashed low/high guides instead of a band."),
    .init(name: "7 · Distance from target", note: "Bars grow up/down from 120 mg/dL."),
    .init(name: "8 · Step line", note: "Stairs between readings, colored by range."),
    .init(name: "9 · Sparkline + high/low labels", note: "Thin line, highest and lowest value labeled."),
    .init(name: "10 · Forecast", note: "Colored history + dashed 20-min projection from the trend."),
    .init(name: "11 · Neon glow", note: "Colored line with a soft glow on black."),
    .init(name: "12 · Range ribbon", note: "A strip: each slice is one reading's color. Tiny but clear."),
    .init(name: "13 · Time in range", note: "Donut: % low / in range / high for the last 3 h."),
    .init(name: "14 · Ring history", note: "Last 3 h drawn around the number, newest brightest."),
]

extension View {
    func plain(_ x: ClosedRange<Date> = start...now, y: ClosedRange<Double> = yDomain) -> some View {
        chartXAxis(.hidden).chartYAxis(.hidden)
            .chartXScale(domain: x).chartYScale(domain: y)
    }
}

@ViewBuilder
func graph(_ index: Int, compact: Bool) -> some View {
    let lw: CGFloat = compact ? 2 : 3
    switch index {
    case 0:
        Chart(data) {
            LineMark(x: .value("t", $0.date), y: .value("v", $0.v))
                .interpolationMethod(.catmullRom).lineStyle(.init(lineWidth: lw, lineCap: .round))
                .foregroundStyle(rangeGradient())
        }.plain()
    case 1:
        Chart(data) {
            LineMark(x: .value("t", $0.date), y: .value("v", $0.v))
                .interpolationMethod(.catmullRom).lineStyle(.init(lineWidth: lw, lineCap: .round))
                .foregroundStyle(rangeGradient(soft: 18))
        }.plain()
    case 2:
        Chart(data) {
            PointMark(x: .value("t", $0.date), y: .value("v", $0.v))
                .symbolSize(compact ? 10 : 20).foregroundStyle(rangeColor($0.v))
        }.plain()
    case 3:
        // Fill colored by height like the line, fading out toward the bottom.
        let area = Chart(data) {
            AreaMark(x: .value("t", $0.date), yStart: .value("b", yDomain.lowerBound), yEnd: .value("v", $0.v))
                .interpolationMethod(.catmullRom)
                .foregroundStyle(rangeGradient(from: yDomain.lowerBound, soft: 12).opacity(0.45))
        }.plain()
            .mask(LinearGradient(colors: [.white, .white.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom))
        let line = Chart(data) {
            LineMark(x: .value("t", $0.date), y: .value("v", $0.v))
                .interpolationMethod(.catmullRom).lineStyle(.init(lineWidth: lw))
                .foregroundStyle(rangeGradient())
        }.plain()
        ZStack { area; line }
    case 4:
        let bars = stride(from: 0, to: data.count - 2, by: 3).map { i -> Point in
            let slice = data[i..<min(i + 3, data.count)]
            return Point(id: i, date: slice.last!.date, v: slice.map(\.v).reduce(0, +) / Double(slice.count))
        }
        Chart(bars) {
            BarMark(x: .value("t", $0.date), yStart: .value("b", yDomain.lowerBound), yEnd: .value("v", $0.v),
                    width: .fixed(compact ? 5 : 9))
                .cornerRadius(compact ? 2 : 4).foregroundStyle(rangeColor($0.v))
        }.plain(start.addingTimeInterval(-300)...now.addingTimeInterval(300))
    case 5:
        Chart {
            RuleMark(y: .value("low", low)).lineStyle(.init(lineWidth: 1, dash: [3, 3])).foregroundStyle(.gray.opacity(0.6))
            RuleMark(y: .value("high", high)).lineStyle(.init(lineWidth: 1, dash: [3, 3])).foregroundStyle(.gray.opacity(0.6))
            ForEach(data) {
                LineMark(x: .value("t", $0.date), y: .value("v", $0.v))
                    .interpolationMethod(.catmullRom).lineStyle(.init(lineWidth: lw))
                    .foregroundStyle(rangeGradient())
            }
        }.plain()
    case 6:
        Chart {
            RuleMark(y: .value("target", target)).foregroundStyle(.gray.opacity(0.5))
            ForEach(data) {
                BarMark(x: .value("t", $0.date), yStart: .value("target", target), yEnd: .value("v", $0.v),
                        width: .fixed(compact ? 2 : 3))
                    .foregroundStyle(rangeColor($0.v))
            }
        }.plain()
    case 7:
        Chart(data) {
            LineMark(x: .value("t", $0.date), y: .value("v", $0.v))
                .interpolationMethod(.stepCenter).lineStyle(.init(lineWidth: lw))
                .foregroundStyle(rangeGradient())
        }.plain()
    case 8:
        let maxP = data.max { $0.v < $1.v }!, minP = data.min { $0.v < $1.v }!
        Chart {
            ForEach(data) {
                LineMark(x: .value("t", $0.date), y: .value("v", $0.v))
                    .interpolationMethod(.catmullRom).lineStyle(.init(lineWidth: compact ? 1.5 : 2))
                    .foregroundStyle(rangeGradient())
            }
            PointMark(x: .value("t", maxP.date), y: .value("v", maxP.v)).symbolSize(compact ? 8 : 14).foregroundStyle(orange)
                .annotation(position: .top, spacing: 1) { Text("218").font(.system(size: compact ? 8 : 10, weight: .semibold, design: .rounded)).foregroundStyle(orange) }
            PointMark(x: .value("t", minP.date), y: .value("v", minP.v)).symbolSize(compact ? 8 : 14).foregroundStyle(red)
                .annotation(position: .bottom, spacing: 1) { Text("61").font(.system(size: compact ? 8 : 10, weight: .semibold, design: .rounded)).foregroundStyle(red) }
        }.plain(y: 20...260)
    case 9:
        Chart {
            ForEach(data) {
                LineMark(x: .value("t", $0.date), y: .value("v", $0.v), series: .value("s", "history"))
                    .interpolationMethod(.catmullRom).lineStyle(.init(lineWidth: lw))
                    .foregroundStyle(rangeGradient())
            }
            ForEach(forecast) {
                LineMark(x: .value("t", $0.date), y: .value("v", $0.v), series: .value("s", "forecast"))
                    .lineStyle(.init(lineWidth: compact ? 1.5 : 2, dash: [3, 3])).foregroundStyle(.white.opacity(0.6))
            }
        }.plain(start...now.addingTimeInterval(20 * 60))
    case 10:
        let line = Chart(data) {
            LineMark(x: .value("t", $0.date), y: .value("v", $0.v))
                .interpolationMethod(.catmullRom).lineStyle(.init(lineWidth: lw, lineCap: .round))
                .foregroundStyle(rangeGradient())
        }.plain()
        ZStack { line.blur(radius: compact ? 3 : 5).opacity(0.9); line }
    case 11:
        Chart(data) {
            RectangleMark(xStart: .value("s", $0.date.addingTimeInterval(-150)), xEnd: .value("e", $0.date.addingTimeInterval(150)),
                          yStart: .value("b", 0), yEnd: .value("t", 1))
                .foregroundStyle(rangeColor($0.v))
        }
        .plain(start.addingTimeInterval(-150)...now.addingTimeInterval(150), y: 0...1)
        .clipShape(Capsule())
        .frame(height: compact ? 8 : 12)
    case 12:
        let lowN = Double(values.filter { $0 < low }.count), highN = Double(values.filter { $0 > high }.count)
        let inN = Double(values.count) - lowN - highN
        HStack(spacing: compact ? 6 : 10) {
            Chart {
                SectorMark(angle: .value("in", inN), innerRadius: .ratio(0.62), angularInset: 1.5).foregroundStyle(green)
                SectorMark(angle: .value("high", highN), innerRadius: .ratio(0.62), angularInset: 1.5).foregroundStyle(orange)
                SectorMark(angle: .value("low", lowN), innerRadius: .ratio(0.62), angularInset: 1.5).foregroundStyle(red)
            }
            .overlay { Text("\(Int((inN / Double(values.count) * 100).rounded()))%").font(.system(size: compact ? 10 : 13, weight: .bold, design: .rounded)) }
            .aspectRatio(1, contentMode: .fit)
            VStack(alignment: .leading, spacing: 1) {
                Text("In range \(pct(inN))").foregroundStyle(green)
                Text("High \(pct(highN))").foregroundStyle(orange)
                Text("Low \(pct(lowN))").foregroundStyle(red)
            }.font(.system(size: compact ? 9 : 11, weight: .medium, design: .rounded))
        }
    default:
        RingHistory(lineWidth: compact ? 4 : 9)
    }
}

func pct(_ n: Double) -> String { "\(Int((n / Double(values.count) * 100).rounded()))%" }

/// Last 3 hours around a circle like a clock; newest at the top, older fades out.
struct RingHistory: View {
    var lineWidth: CGFloat
    var body: some View {
        Canvas { context, size in
            let r = min(size.width, size.height) / 2 - lineWidth / 2
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let n = data.count
            for (i, p) in data.enumerated() {
                let a0 = -90.0 + Double(i) / Double(n) * 360 + 1.5
                let a1 = -90.0 + Double(i + 1) / Double(n) * 360 - 1.5
                var path = Path()
                path.addArc(center: c, radius: r, startAngle: .degrees(a0), endAngle: .degrees(a1), clockwise: false)
                let opacity = 0.25 + 0.75 * Double(i) / Double(n - 1)
                context.stroke(path, with: .color(rangeColor(p.v).opacity(opacity)), style: .init(lineWidth: lineWidth, lineCap: .butt))
            }
        }
    }
}

// MARK: - Building blocks

struct Watch<Content: View>: View {
    let title: String
    let note: String
    var background: AnyShapeStyle = AnyShapeStyle(Color.black)
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 6) {
            ZStack { content }
                .frame(width: 198, height: 242)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: 46, style: .continuous))
                .padding(7)
                .background(RoundedRectangle(cornerRadius: 52, style: .continuous).fill(bezel))
            Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
            Text(note).font(.system(size: 11)).foregroundStyle(Color(white: 0.65))
                .multilineTextAlignment(.center).frame(width: 210, height: 30, alignment: .top)
        }
    }
}

struct Clock: View {
    var size: CGFloat = 30
    var body: some View {
        Text("10:42").font(.system(size: size, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(.white)
    }
}

struct BigValue: View {
    var size: CGFloat = 56
    var color: Color = green
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text("134").font(.system(size: size, weight: .bold, design: .rounded)).monospacedDigit()
            Text("↗").font(.system(size: size * 0.55, weight: .bold))
        }.foregroundStyle(color)
    }
}

struct SubLine: View {
    var text = "+4 · 1 min"
    var body: some View {
        Text(text).font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(Color(white: 0.6))
    }
}

struct Steps: View {
    var body: some View {
        Label("6,214", systemImage: "figure.walk").font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(.white)
    }
}

struct StandardApp<G: View>: View {
    @ViewBuilder var graph: G
    var body: some View {
        VStack(spacing: 0) {
            Clock()
            BigValue()
            SubLine()
            graph.frame(height: 58).padding(.horizontal, 10).padding(.top, 6)
            Spacer(minLength: 0)
            Steps()
        }.padding(.top, 10).padding(.bottom, 14)
    }
}

/// A rectangular complication slot as it sits on a black face.
struct Slot<Content: View>: View {
    let title: String
    let note: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 5) {
            content
                .frame(width: 172, height: 74)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.black))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(bezel, lineWidth: 2))
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
            Text(note).font(.system(size: 10.5)).foregroundStyle(Color(white: 0.65))
                .multilineTextAlignment(.center).frame(width: 196, height: 28, alignment: .top)
        }
    }
}

struct RectValue: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("134").font(.system(size: 30, weight: .bold, design: .rounded))
                Text("↗").font(.system(size: 18, weight: .bold))
            }.foregroundStyle(green)
            Text("+4 · 1m").font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(Color(white: 0.6))
        }.fixedSize()
    }
}

struct Circle52<Content: View>: View {
    let title: String
    let note: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle().fill(Color(white: 0.12))
                content
            }
            .frame(width: 92, height: 92)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.black))
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
            Text(note).font(.system(size: 10.5)).foregroundStyle(Color(white: 0.65))
                .multilineTextAlignment(.center).frame(width: 150, height: 28, alignment: .top)
        }
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

// MARK: - Sheets

struct AppGraphsSheet: View {
    var body: some View {
        Sheet(title: "Watch app: 14 graph styles",
              subtitle: "Same screen, only the graph changes. Colors come from the line itself: red below 70, green 70–180, orange above 180.") {
            Grid(horizontalSpacing: 22, verticalSpacing: 22) {
                ForEach(0..<4) { row in
                    GridRow {
                        ForEach(0..<4) { col in
                            let i = row * 4 + col
                            if i < 13 {
                                Watch(title: graphVariants[i].name, note: graphVariants[i].note) {
                                    StandardApp { graph(i, compact: false) }
                                }
                            } else if i == 13 {
                                Watch(title: graphVariants[13].name, note: graphVariants[13].note) {
                                    ZStack {
                                        graph(13, compact: false).frame(width: 176, height: 176)
                                        VStack(spacing: 0) {
                                            Clock(size: 18)
                                            BigValue(size: 48)
                                            SubLine()
                                        }
                                    }
                                    .frame(maxHeight: .infinity)
                                    .overlay(alignment: .bottom) { Steps().padding(.bottom, 8) }
                                }
                            } else {
                                Color.clear.frame(width: 1, height: 1)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct WidgetGraphsSheet: View {
    var body: some View {
        Sheet(title: "Complications: 12 rectangular + 6 small",
              subtitle: "Rectangular slot (Modular, Modular Duo, Smart Stack). In tinted faces, watchOS may recolor everything to one tint.") {
            Grid(horizontalSpacing: 20, verticalSpacing: 20) {
                ForEach(0..<3) { row in
                    GridRow {
                        ForEach(0..<4) { col in
                            let i = row * 4 + col
                            rectVariant(i)
                        }
                    }
                }
            }
            Text("Small slots").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white).padding(.top, 8)
            HStack(alignment: .top, spacing: 18) {
                Circle52(title: "A · Ring history", note: "Last 3 h around the value") {
                    RingHistory(lineWidth: 5).padding(4)
                    VStack(spacing: -3) {
                        Text("134").font(.system(size: 26, weight: .bold, design: .rounded)).foregroundStyle(green)
                        Text("↗").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                    }
                }
                Circle52(title: "B · Range gauge", note: "Arc low → high, dot = now") {
                    Gauge(value: 134, in: 40...300) { EmptyView() } currentValueLabel: {
                        Text("134").font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(green)
                    }
                    .gaugeStyle(.accessoryCircular).tint(Gradient(colors: [red, green, green, orange])).scaleEffect(1.5)
                }
                Circle52(title: "C · Time in range", note: "Donut + current value") {
                    graph(12, compact: true).hidden()
                    Chart {
                        SectorMark(angle: .value("in", 24), innerRadius: .ratio(0.78), angularInset: 2).foregroundStyle(green)
                        SectorMark(angle: .value("high", 7), innerRadius: .ratio(0.78), angularInset: 2).foregroundStyle(orange)
                        SectorMark(angle: .value("low", 6), innerRadius: .ratio(0.78), angularInset: 2).foregroundStyle(red)
                    }.padding(4)
                    Text("134").font(.system(size: 26, weight: .bold, design: .rounded)).foregroundStyle(green)
                }
                Circle52(title: "D · Mini line", note: "Value over a 1 h colored line") {
                    graph(0, compact: true).frame(width: 66, height: 26).offset(y: 18).opacity(0.9)
                    Text("134").font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(green).offset(y: -10)
                }
                Circle52(title: "E · Trend arrow badge", note: "Big arrow, value under it") {
                    VStack(spacing: -4) {
                        Image(systemName: "arrow.up.right").font(.system(size: 24, weight: .heavy)).foregroundStyle(green)
                        Text("134").font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    }
                }
                Circle52(title: "F · Corner", note: "Value + range bar along the edge") {
                    ZStack(alignment: .topLeading) {
                        Circle().trim(from: 0.55, to: 0.7).stroke(
                            AngularGradient(colors: [red, green, green, orange], center: .center, startAngle: .degrees(198), endAngle: .degrees(252)),
                            style: .init(lineWidth: 6, lineCap: .round))
                            .frame(width: 140, height: 140).offset(x: 6, y: 6)
                        Text("134↗").font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(green)
                            .rotationEffect(.degrees(-45)).offset(x: 16, y: 20)
                    }.frame(width: 92, height: 92, alignment: .topLeading).clipped()
                }
            }
        }
    }

    @ViewBuilder
    func rectVariant(_ i: Int) -> some View {
        // Which graph style each rectangular idea uses.
        let picks: [(Int, String)] = [(0, ""), (1, ""), (2, ""), (3, ""), (4, ""), (5, ""), (6, ""), (8, ""), (9, ""), (10, ""), (11, "ribbon"), (12, "tir")]
        let (g, kind) = picks[i]
        Slot(title: graphVariants[g].name, note: graphVariants[g].note) {
            switch kind {
            case "ribbon":
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        RectValue()
                        Spacer()
                        Text("3 h").font(.system(size: 11, design: .rounded)).foregroundStyle(.gray)
                    }
                    graph(11, compact: true)
                }
            case "tir":
                HStack(spacing: 10) {
                    RectValue()
                    graph(12, compact: true)
                }
            default:
                HStack(spacing: 6) {
                    RectValue()
                    graph(g, compact: true)
                }
            }
        }
    }
}

struct LayoutsSheet: View {
    var body: some View {
        Sheet(title: "Watch app: 5 layouts + a better 'no connection' state",
              subtitle: "Time and glucose stay fixed in every layout. Pages (E) are swiped with the Digital Crown.") {
            HStack(alignment: .top, spacing: 22) {
                Watch(title: "A · Classic", note: "Today's layout, cleaned up; colored line") {
                    StandardApp { graph(0, compact: false) }
                }
                Watch(title: "B · Ring", note: "Value inside a 3 h ring; clock on top") {
                    ZStack {
                        graph(13, compact: false).frame(width: 176, height: 176)
                        VStack(spacing: 0) { Clock(size: 18); BigValue(size: 48); SubLine() }
                    }
                }
                Watch(title: "C · Color wash", note: "Background softly tinted by range",
                      background: AnyShapeStyle(LinearGradient(colors: [green.opacity(0.55), .black], startPoint: .top, endPoint: .bottom))) {
                    VStack(spacing: 0) {
                        Clock()
                        BigValue(size: 62, color: .white)
                        SubLine(text: "+4 · 1 min").foregroundStyle(.white)
                        graph(0, compact: false).frame(height: 50).padding(.horizontal, 10).padding(.top, 4)
                        Spacer(minLength: 0)
                        Steps()
                    }.padding(.top, 10).padding(.bottom, 14)
                }
                Watch(title: "D · Huge number", note: "Max legibility; ribbon instead of graph") {
                    VStack(spacing: 2) {
                        Clock(size: 26)
                        Spacer(minLength: 0)
                        BigValue(size: 74).lineLimit(1).fixedSize()
                        SubLine()
                        graph(11, compact: false).padding(.horizontal, 18).padding(.top, 6)
                        Spacer(minLength: 0)
                        Steps()
                    }.padding(.top, 10).padding(.bottom, 14)
                }
                Watch(title: "F · No connection", note: "Instead of 'cancelled': calm, says what you see") {
                    VStack(spacing: 0) {
                        Clock()
                        BigValue(color: .gray)
                        HStack(spacing: 4) {
                            Image(systemName: "wifi.slash")
                            Text("Reading from 10:23")
                        }.font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(orange)
                        graph(0, compact: false).grayscale(1).opacity(0.6).frame(height: 50).padding(.horizontal, 10).padding(.top, 6)
                        Spacer(minLength: 0)
                        Steps()
                    }.padding(.top, 10).padding(.bottom, 14)
                }
            }
            Text("E · Pages").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white).padding(.top, 8)
            HStack(alignment: .top, spacing: 22) {
                Watch(title: "Page 1 · Now", note: "Time + value, nothing else") {
                    VStack(spacing: 4) { Clock(size: 32); Spacer(minLength: 0); BigValue(size: 80); SubLine(); Spacer(minLength: 0) }
                        .padding(.vertical, 14)
                }
                Watch(title: "Page 2 · Graph", note: "3 h / 6 h / 12 h, crown to zoom") {
                    VStack(spacing: 6) {
                        HStack { Clock(size: 18); Spacer(); Text("134 ↗").font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(green) }
                            .padding(.horizontal, 22)
                        Chart(data) {
                            RuleMark(y: .value("l", low)).lineStyle(.init(lineWidth: 1, dash: [2, 3])).foregroundStyle(.gray.opacity(0.5))
                            RuleMark(y: .value("h", high)).lineStyle(.init(lineWidth: 1, dash: [2, 3])).foregroundStyle(.gray.opacity(0.5))
                            LineMark(x: .value("t", $0.date), y: .value("v", $0.v))
                                .interpolationMethod(.catmullRom).lineStyle(.init(lineWidth: 3)).foregroundStyle(rangeGradient())
                        }
                        .chartYScale(domain: yDomain).chartXScale(domain: start...now)
                        .chartXAxis { AxisMarks(values: .stride(by: .hour)) { _ in AxisGridLine().foregroundStyle(.gray.opacity(0.3)); AxisValueLabel(format: .dateTime.hour()) } }
                        .chartYAxis { AxisMarks(position: .trailing, values: [70, 180]) { AxisValueLabel() } }
                        .padding(.horizontal, 12)
                        HStack(spacing: 6) {
                            ForEach(["3h", "6h", "12h"], id: \.self) { s in
                                Text(s).font(.system(size: 11, weight: .semibold)).padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Capsule().fill(s == "3h" ? Color(white: 0.3) : Color(white: 0.12)))
                            }
                        }.foregroundStyle(.white)
                    }.padding(.vertical, 14)
                }
                Watch(title: "Page 3 · Today", note: "Time in range, average, steps") {
                    VStack(spacing: 8) {
                        Clock(size: 18)
                        graph(12, compact: false).frame(height: 64).padding(.horizontal, 16)
                        HStack(spacing: 18) {
                            VStack(spacing: 0) { Text("128").font(.system(size: 22, weight: .bold, design: .rounded)); Text("average").font(.system(size: 10)).foregroundStyle(.gray) }
                            VStack(spacing: 0) { Text("6,214").font(.system(size: 22, weight: .bold, design: .rounded)); Text("steps").font(.system(size: 10)).foregroundStyle(.gray) }
                        }.foregroundStyle(.white)
                    }.padding(.vertical, 14)
                }
            }
        }
    }
}

// MARK: - Render

@main
struct Render {
    @MainActor static func main() throws {
        let dir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
        try save(AppGraphsSheet(), to: "\(dir)/1-app-graphs.png")
        try save(WidgetGraphsSheet(), to: "\(dir)/2-complication-graphs.png")
        try save(LayoutsSheet(), to: "\(dir)/3-app-layouts.png")
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
