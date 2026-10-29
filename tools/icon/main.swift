// Renders the app icon master (1024 px). Usage: swift tools/icon/main.swift out.png, then see docs/adr/0014.
import SwiftUI
import AppKit

let green = Color(red: 0.20, green: 0.80, blue: 0.40)
let orange = Color(red: 1.0, green: 0.62, blue: 0.15)
let red = Color(red: 1.0, green: 0.27, blue: 0.27)

struct Base<Content: View>: View {
    let colors: [Color]
    @ViewBuilder let content: Content
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
                .frame(width: 824, height: 824)
                .shadow(color: .black.opacity(0.35), radius: 24, y: 14)
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .top, endPoint: .center), lineWidth: 4)
                .frame(width: 824, height: 824)
            content.frame(width: 824, height: 824)
        }
        .frame(width: 1024, height: 1024)
    }
}

struct Gauge: View {
    var body: some View {
        Base(colors: [Color(red: 0.14, green: 0.16, blue: 0.30), Color(red: 0.05, green: 0.06, blue: 0.14)]) {
            ZStack {
                Circle().trim(from: 0, to: 0.75).rotation(.degrees(135))
                    .stroke(.white.opacity(0.14), style: StrokeStyle(lineWidth: 100, lineCap: .round))
                    .frame(width: 640, height: 640)
                Circle().trim(from: 0, to: 0.75 * 0.68).rotation(.degrees(135))
                    .stroke(AngularGradient(colors: [red, orange, green], center: .center, startAngle: .degrees(135), endAngle: .degrees(405)),
                            style: StrokeStyle(lineWidth: 100, lineCap: .round))
                    .frame(width: 640, height: 640)
                Capsule().fill(.white).frame(width: 38, height: 270).offset(y: -135)
                    .rotationEffect(.degrees(-135 + 270 * 0.68))
                Circle().fill(.white).frame(width: 96, height: 96)
            }.offset(y: 26)
        }
    }
}

@MainActor func run() {
    let out = CommandLine.arguments[1]
    let r = ImageRenderer(content: Gauge())
    if let t = r.nsImage?.tiffRepresentation, let rep = NSBitmapImageRep(data: t),
       let d = rep.representation(using: .png, properties: [:]) { try? d.write(to: URL(fileURLWithPath: out)) }
}
MainActor.assumeIsolated { run() }
