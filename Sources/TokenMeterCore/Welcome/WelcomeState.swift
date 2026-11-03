import Foundation

/// Where the welcome tour is (feature "welcome tour", [ADR 0014](../../../docs/adr/0014-welcome-tour.md)). A pure value: the app draws
/// what it says and keeps only whether the tour was seen.
///
/// The tour starts by itself once, when it was never seen: on a fresh install and on the first update. It counts as seen when it is
/// finished, skipped or declined with "Not now", never when it is only started, so one that was interrupted starts again.
public enum WelcomeState: Equatable, Sendable {
    /// The places of the tour, in the order the person meets them.
    public enum Stop: Int, CaseIterable, Sendable {
        /// The popover under the menu-bar icon.
        case icon
        case bars
        case tick
        case buttons
        case stats
        case suggestion
        case settings
        /// What the app set up on its own, the last screen.
        case summary

        /// The stops that have a caption "n of 6" (the icon and the summary have none).
        public var captionNumber: Int? {
            switch self {
            case .icon, .summary: nil
            default: rawValue
            }
        }
    }

    /// The tour is not showing: it was seen, or it is waiting for the panel.
    case idle
    case running(Stop)

    /// The state at launch: running at the icon if the tour was never seen, idle otherwise.
    public static func atLaunch(seen: Bool) -> WelcomeState { seen ? .idle : .running(.icon) }

    public var stop: Stop? {
        if case .running(let stop) = self { stop } else { nil }
    }

    /// True while the tour is showing, so the panel is dimmed and a caption is drawn.
    public var isRunning: Bool { stop != nil }

    /// "Show me" on the popover and "Next" at every stop: the next place, and finished after the summary. Idle stays idle.
    public func advanced() -> WelcomeState {
        guard case .running(let stop) = self else { return self }
        guard let next = Stop(rawValue: stop.rawValue + 1) else { return .idle }
        return .running(next)
    }

    /// Whether the tour was just ended and has to be remembered as seen: it ran to its last stop, or it was skipped or declined.
    public func endedBy(_ action: Action) -> Bool {
        switch (self, action) {
        case (.running(.summary), .next): true
        case (.running, .skip), (.running(.icon), .notNow): true
        default: false
        }
    }

    public enum Action: Equatable, Sendable {
        case next
        case skip
        /// "Not now" on the popover: ends the tour without showing it.
        case notNow
    }

    /// The state after `action`.
    public func applying(_ action: Action) -> WelcomeState {
        switch action {
        case .next: advanced()
        case .skip, .notNow: .idle
        }
    }

    /// "Show the welcome again" in Settings: from the popover, whatever was seen.
    public static let again = WelcomeState.running(.icon)
}

/// Whether the tour was seen. The app keeps it in its defaults.
public protocol WelcomeSeenStore: Sendable {
    var seen: Bool { get }
    func markSeen()
}

/// Kept in memory; for tests.
public final class MemoryWelcomeSeenStore: WelcomeSeenStore, @unchecked Sendable {
    private let lock = NSLock()
    private var value: Bool

    public init(seen: Bool = false) { value = seen }

    public var seen: Bool { lock.withLock { value } }
    public func markSeen() { lock.withLock { value = true } }
}

/// Kept in the app's defaults.
public struct DefaultsWelcomeSeenStore: WelcomeSeenStore, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "welcomeSeen") {
        self.defaults = defaults
        self.key = key
    }

    public var seen: Bool { defaults.bool(forKey: key) }
    public func markSeen() { defaults.set(true, forKey: key) }
}
