import Foundation

/// Where the welcome wizard is (feature "welcome tour"). A pure value: the app draws the page and keeps only whether the wizard was seen.
///
/// The wizard opens by itself once, when it was never seen: on a fresh install and on the first update. It counts as seen when the
/// person reaches Done, skips it or closes its window, never when the app quits in the middle, so an interrupted one opens again.
public enum WelcomeState: Equatable, Sendable {
    /// The pages, in the order the person meets them.
    public enum Page: Int, CaseIterable, Sendable {
        case whereItLives
        case bars
        case tick
        case buttons
        case stats
        case suggestion
        case settings

        public var isFirst: Bool { self == Page.allCases.first }
        public var isLast: Bool { self == Page.allCases.last }
    }

    /// What the person does in the footer, or to the window.
    public enum Action: Equatable, Sendable {
        case back
        /// "Next", and "Done" on the last page.
        case next
        case skip
        /// The red button of the window.
        case close
    }

    /// The wizard is not showing: it was seen, or it was never opened.
    case idle
    case showing(Page)

    /// The state at launch: the first page if the wizard was never seen, idle otherwise.
    public static func atLaunch(seen: Bool) -> WelcomeState { seen ? .idle : .showing(.whereItLives) }

    /// "Show the welcome again" in Settings: the first page, whatever was seen.
    public static let again = WelcomeState.showing(.whereItLives)

    public var page: Page? {
        if case .showing(let page) = self { page } else { nil }
    }

    public var isShowing: Bool { page != nil }

    /// The state after `action`. Back on the first page stays there, and Next on the last page ends it.
    public func applying(_ action: Action) -> WelcomeState {
        guard case .showing(let page) = self else { return self }
        switch action {
        case .back:
            return .showing(Page(rawValue: page.rawValue - 1) ?? page)
        case .next:
            return Page(rawValue: page.rawValue + 1).map { .showing($0) } ?? .idle
        case .skip, .close:
            return .idle
        }
    }

    /// Whether `action` ends the wizard in a way that counts as seen: Done, skip or closing the window.
    public func endedBy(_ action: Action) -> Bool {
        guard isShowing else { return false }
        return applying(action) == .idle
    }
}

/// Whether the wizard was seen. The app keeps it in its defaults.
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
