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

/// The icon of the event on a bar, in a box 34 points wide and 24 high, centred on `position` (a fraction of the bar's width). Where the quota will
/// not last the plain orange tick stays: a warning is never replaced by a joke, so callers use this only where it lasts.
struct EasterEggMark: View {
    let egg: EasterEgg
    let position: CGFloat
    let barWidth: CGFloat

    /// Every mark has a 34 × 24 point canvas, with its drawing optically balanced inside it and an exact 2× representation.
    static let width: CGFloat = 34
    static let height: CGFloat = 24

    var body: some View {
        EasterEggImage(name: egg.mark)
            .frame(width: Self.width, height: Self.height)
            .offset(x: barWidth * min(max(position, 0), 1) - Self.width / 2)
            .allowsHitTesting(false)
    }
}

extension View {
    /// The corner piece of the event across the top right corner of a card, overhanging it a little as if pinned on.
    func easterEggCorner() -> some View { modifier(EasterEggCorner()) }
}

private struct EasterEggCorner: ViewModifier {
    @Environment(\.easterEgg) private var egg

    static let size: CGFloat = 44
    /// How far it sticks out past the card to the right, and above it: above enough to stay clear of the first row of figures.
    static let overhangX: CGFloat = 8
    static let overhangY: CGFloat = 10

    func body(content: Content) -> some View {
        content.overlay(alignment: .topTrailing) {
            if let egg {
                EasterEggImage(name: egg.corner)
                    .frame(width: Self.size, height: Self.size)
                    .offset(x: Self.overhangX, y: -Self.overhangY)
                    .allowsHitTesting(false)
            }
        }
    }
}
