import AppKit

/// The menu-bar item: the app icon's gauge as a template image, so it follows the light and dark
/// menu bar. The dim track and the full arc stand in for the icon's grey track and coloured arc.
enum MenuBarIcon {
    static let image: NSImage = {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY - 0.5)
            let radius: CGFloat = 6.6
            let level = 0.68
            let start: CGFloat = 225
            let end: CGFloat = -45
            let valueEnd = start - (start - end) * level

            func arc(from: CGFloat, to: CGFloat, alpha: CGFloat) {
                let path = NSBezierPath()
                path.appendArc(withCenter: center, radius: radius, startAngle: from, endAngle: to, clockwise: true)
                path.lineWidth = 2.2
                path.lineCapStyle = .round
                NSColor.black.withAlphaComponent(alpha).setStroke()
                path.stroke()
            }
            arc(from: start, to: end, alpha: 0.35)
            arc(from: start, to: valueEnd, alpha: 1)

            let radians = valueEnd * .pi / 180
            let needle = NSBezierPath()
            needle.move(to: center)
            needle.line(to: NSPoint(x: center.x + 5.2 * cos(radians), y: center.y + 5.2 * sin(radians)))
            needle.lineWidth = 1.8
            needle.lineCapStyle = .round
            NSColor.black.setStroke()
            needle.stroke()

            NSColor.black.setFill()
            NSBezierPath(ovalIn: NSRect(x: center.x - 1.9, y: center.y - 1.9, width: 3.8, height: 3.8)).fill()
            return true
        }
        image.isTemplate = true
        return image
    }()
}
