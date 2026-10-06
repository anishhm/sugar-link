import AppKit
import SwiftUI

/// The app icon ("Drift"): the white trend arrow on a green gradient.
/// watchOS crops it to a circle, so the arrow sits in the middle.
/// Run from the project folder: swiftc -parse-as-library scripts/generate_icon.swift -o /tmp/icon && /tmp/icon
let green = Color(red: 0.19, green: 0.82, blue: 0.35)
let deepGreen = Color(red: 0.08, green: 0.55, blue: 0.30)

struct IconView: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            LinearGradient(colors: [green, deepGreen], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "arrow.forward")
                .font(.system(size: size * 0.42, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(-30))
        }
        .frame(width: size, height: size)
    }
}

/// Big and real-size previews, circular as on the watch.
struct Preview: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 24) {
            IconView(size: 260).clipShape(Circle())
            IconView(size: 80).clipShape(Circle())
            IconView(size: 44).clipShape(Circle())
        }
        .padding(30)
        .background(Color.black)
    }
}

@main
struct GenerateIcon {
    @MainActor static func main() throws {
        func png<V: View>(_ view: V) -> Data {
            let r = ImageRenderer(content: view)
            r.scale = 1
            r.isOpaque = true // App Store tools reject icons with a transparency channel
            return NSBitmapImageRep(cgImage: r.cgImage!).representation(using: .png, properties: [:])!
        }
        let root = "" // run from the project folder
        try png(IconView(size: 1024)).write(to: URL(fileURLWithPath: root + "Watch/Assets.xcassets/AppIcon.appiconset/AppIcon.png"))
        try png(Preview()).write(to: URL(fileURLWithPath: root + "docs/screenshots/icon.png"))
    }
}
