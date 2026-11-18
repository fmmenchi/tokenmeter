import Foundation

/// One figure of the menu bar: a card of the panel and its tightest window, as the bar writes it and as it is said in words.
public struct MenuBarFigure: Equatable, Sendable {
    /// The card's name, as the panel shows it.
    public let title: String
    /// What the bar writes: `31%`, `~31%`, or `—` when the card has no figure.
    public let text: String
    /// What the tooltip and VoiceOver say: `Claude 31% left`, `Claude about 31% left, 25m ago`, `Claude no figure yet`.
    public let spoken: String
    /// What is left of the tightest window, 0 to 1; nil when the card has no figure.
    public let remaining: Double?
}

/// The quota in the menu bar (docs/features/2026-11-17-menu-bar-quota): one figure per card, in the order of the panel, each the
/// window of the card with the least left. The cards are the snapshot as the person wants to see it, so the order and the hidden
/// cards are the panel's (ADR 0006).
public enum MenuBarFigures {
    /// More cards than this and the bar shows one figure, the tightest of all: macOS hides an item that does not fit and does not
    /// tell the app, so the bar keeps short instead. A guess, to be checked on a real bar.
    public static let crowdedAfter = 3

    /// The window of a card with the least left, as it reads at `now`. A model's limit is a part of a window of the card and does
    /// not count; a window with no figure does not count; nil when none has one.
    public static func tightest(of card: ProviderSnapshot, at now: Date) -> WindowUsage? {
        card.windows
            .filter { $0.window.scope == nil }
            .map { card.resolved($0, at: now) }
            .filter { $0.remainingFraction != nil }
            .min { ($0.remainingFraction ?? 1) < ($1.remainingFraction ?? 1) }
    }

    /// One figure per card of `snapshot`, in its order.
    public static func figures(of snapshot: Snapshot, display: BarsDisplay, at now: Date) -> [MenuBarFigure] {
        snapshot.providers.map { card in
            guard let window = tightest(of: card, at: now), let remaining = window.remainingFraction else {
                return MenuBarFigure(title: card.title, text: "—", spoken: "\(card.title) no figure yet", remaining: nil)
            }
            let approximate = window.isApproximate(at: now)
            var spoken = "\(card.title) \(approximate ? "about " : "")\(display.figure(remaining: remaining))"
            if window.isStale(at: now), let ago = window.observedAgoText(at: now) { spoken += ", \(ago)" }
            return MenuBarFigure(title: card.title, text: window.figureText(display, at: now), spoken: spoken, remaining: remaining)
        }
    }

    /// The figures the bar writes: all of them, or, with more than `crowdedAfter`, the one with the least left of all (the first
    /// card when none has a figure).
    public static func shown(_ figures: [MenuBarFigure]) -> [MenuBarFigure] {
        guard figures.count > crowdedAfter else { return figures }
        let tightest = figures.filter { $0.remaining != nil }.min { ($0.remaining ?? 1) < ($1.remaining ?? 1) }
        return [tightest ?? figures[0]]
    }

    /// The text of the tooltip: every figure, in order, the one the bar writes alone named "the tightest"; "needs attention" first
    /// when the dot is on the gauge.
    public static func tooltip(_ figures: [MenuBarFigure], needsAttention: Bool) -> String {
        let alone = figures.count > crowdedAfter ? shown(figures).first : nil
        let parts = figures.map { $0 == alone ? "\($0.spoken), the tightest" : $0.spoken }
        return ((needsAttention ? ["needs attention"] : []) + [parts.joined(separator: " · ")])
            .filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// What VoiceOver says for the item: the app's name, then the tooltip's text, with commas where the tooltip has dots.
    public static func accessibilityLabel(_ figures: [MenuBarFigure], needsAttention: Bool) -> String {
        let text = tooltip(figures, needsAttention: needsAttention).replacingOccurrences(of: " · ", with: ", ")
        return text.isEmpty ? "tokenmeter" : "tokenmeter, \(text)"
    }
}
