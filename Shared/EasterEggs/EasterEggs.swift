import AppKit
import SwiftUI
import TokenMeterCore

// The two places where an event shows in the panel (feature "seasonal easter eggs"): the icon that takes the place of the pace tick
// on a bar whose quota lasts, and the piece across the top right corner of a card. Everything that draws them is here; the views of
// `Shared/` only call these two. The panel sets the value in the environment; the widget never does, so it draws neither.

private struct EasterEggKey: EnvironmentKey {
    static let defaultValue: EasterEgg? = nil
}

extension EnvironmentValues {
    /// What the panel carries during an event, nil on every ordinary day and in the widget.
    var easterEgg: EasterEgg? {
        get { self[EasterEggKey.self] }
        set { self[EasterEggKey.self] = newValue }
    }
}

/// One of the app's pieces, by name. Nothing is drawn when the image is not there, so a missing piece never breaks a card.
struct EasterEggImage: View {
    let name: String

    var body: some View {
        if let image = NSImage(named: name) {
            Image(nsImage: image).resizable().interpolation(.high).scaledToFit().accessibilityHidden(true)
        }
    }
}

/// The icon of the event on a bar, 16 points across, centred on `position` (a fraction of the bar's width). Where the quota will
/// not last the plain orange tick stays: a warning is never replaced by a joke, so callers use this only where it lasts.
struct EasterEggMark: View {
    let egg: EasterEgg
    let position: CGFloat
    let barWidth: CGFloat

    static let size: CGFloat = 16

    var body: some View {
        EasterEggImage(name: egg.mark)
            .frame(width: Self.size, height: Self.size)
            .offset(x: barWidth * min(max(position, 0), 1) - Self.size / 2)
            .allowsHitTesting(false)
    }
}

extension View {
    /// The corner piece of the event across the top right corner of a card, overhanging it a little as if pinned on.
    func easterEggCorner() -> some View { modifier(EasterEggCorner()) }
}

private struct EasterEggCorner: ViewModifier {
    @Environment(\.easterEgg) private var egg

    static let size: CGFloat = 34
    static let overhang: CGFloat = 6

    func body(content: Content) -> some View {
        content.overlay(alignment: .topTrailing) {
            if let egg {
                EasterEggImage(name: egg.corner)
                    .frame(width: Self.size, height: Self.size)
                    .offset(x: Self.overhang, y: -Self.overhang)
                    .allowsHitTesting(false)
            }
        }
    }
}
