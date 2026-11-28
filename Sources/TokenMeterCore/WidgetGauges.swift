import Foundation

/// One gauge of a widget: a window of a card, as it reads at a moment, and the limits of the models that are part of it.
public struct WidgetGauge: Equatable, Sendable {
    /// The window, resolved at the moment asked for.
    public let window: WindowUsage
    /// The limits of models that are part of this window (ADR 0002), resolved, in the card's order.
    public let models: [WindowUsage]

    /// The model's limit with the least left: the one the inner ring draws. nil when no model has a figure.
    public var lowestModel: WindowUsage? {
        models.filter { $0.remainingFraction != nil }.min { ($0.remainingFraction ?? 1) < ($1.remainingFraction ?? 1) }
    }
}

/// What a widget draws (ADR 0018): one card, chosen by the person, and at most two gauges of it.
public enum WidgetGauges {
    /// More gauges than this do not fit a widget: the first ones of the card are drawn.
    public static let most = 2

    /// The card a widget shows: the one with `id`, or the first when no account was chosen. nil when `id` names no card, because
    /// the account was removed or hidden: the widget says so rather than show another one.
    public static func card(withID id: String?, in snapshot: Snapshot) -> ProviderSnapshot? {
        guard let id else { return snapshot.providers.first }
        return snapshot.providers.first { $0.provider.rawValue == id }
    }

    /// The gauges of `card` at `now`: the first `most` windows that are not a model's limit, in the card's order, each with the
    /// limits of models of the same window.
    public static func gauges(of card: ProviderSnapshot, at now: Date) -> [WidgetGauge] {
        card.windows
            .filter { $0.window.scope == nil }
            .prefix(most)
            .map { window in
                let models = card.windows
                    .filter { $0.window.scope != nil && $0.window.name == window.window.name }
                    .map { card.resolved($0, at: now) }
                return WidgetGauge(window: card.resolved(window, at: now), models: models)
            }
    }
}
