import Foundation

/// How the bars read: how much is left, or how much is used (ADR 0006). One choice of the app, `left` by default, that changes the
/// figure, how far the bar is filled and where the pace mark sits. The data is not touched: a window always stores what is left,
/// and the colour of a bar, the notices and the stats keep following it.
public enum BarsDisplay: String, CaseIterable, Codable, Sendable {
    case left
    case used

    /// The word that follows the figure: `25% left`, `75% used`.
    public var word: String { rawValue }

    /// How far a bar is filled, and the figure it says, for a window with `remaining` of its quota left (0 to 1).
    public func fraction(remaining: Double) -> Double {
        switch self {
        case .left: remaining
        case .used: min(max(1 - remaining, 0), 1)
        }
    }

    /// The figure a window says, in whole percent: what is left rounded as it always was, and used as the hundred that remain, so the
    /// two readings of one window always add up to 100.
    public func percent(remaining: Double) -> Int {
        let left = min(max(Int((remaining * 100).rounded()), 0), 100)
        return self == .left ? left : 100 - left
    }

    /// The pace mark as this reading draws it: the bar and the mark are on the same side, so a bar that passes the mark still
    /// means the quota runs out before the reset.
    public func shown(_ pace: Pace) -> Pace {
        switch self {
        case .left: pace
        case .used: Pace(aheadFraction: 1 - pace.aheadFraction, runsOutAt: pace.runsOutAt, isStale: pace.isStale, runsOut: pace.runsOut)
        }
    }
}
