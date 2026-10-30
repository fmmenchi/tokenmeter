import Foundation

/// How the person wants the providers shown: the order of the cards and which windows of each have a row (ADR 0035).
/// Preferences of the app, keyed by provider id; `providers.json` is never written for them.
public protocol DisplayPreferences: Sendable {
    /// Provider ids, first card first. A provider not in the list comes after the ones that are.
    var order: [String] { get }
    /// The windows (by name) shown for a provider; nil means every window.
    func windows(for provider: String) -> Set<String>?
    func setOrder(_ order: [String])
    func setWindows(_ windows: Set<String>?, for provider: String)
}

extension DisplayPreferences {
    /// `ids` in the person's order: the ones they placed first, then the rest as given.
    public func ordered(_ ids: [String]) -> [String] {
        let placed = order.filter(ids.contains)
        return placed + ids.filter { !placed.contains($0) }
    }
}

/// Kept in memory; for tests.
public final class MemoryDisplayPreferences: DisplayPreferences, @unchecked Sendable {
    private let lock = NSLock()
    private var storedOrder: [String] = []
    private var storedWindows: [String: Set<String>] = [:]

    public init() {}

    public var order: [String] { lock.withLock { storedOrder } }

    public func windows(for provider: String) -> Set<String>? { lock.withLock { storedWindows[provider] } }

    public func setOrder(_ order: [String]) { lock.withLock { storedOrder = order } }

    public func setWindows(_ windows: Set<String>?, for provider: String) {
        lock.withLock { storedWindows[provider] = windows }
    }
}

/// Kept in the app's defaults.
public final class DefaultsDisplayPreferences: DisplayPreferences, @unchecked Sendable {
    private let defaults: UserDefaults
    private let orderKey: String
    private let windowsKey: String
    private let lock = NSLock()

    public init(defaults: UserDefaults = .standard, orderKey: String = "providerOrder",
                windowsKey: String = "providerWindows") {
        self.defaults = defaults
        self.orderKey = orderKey
        self.windowsKey = windowsKey
    }

    public var order: [String] { lock.withLock { defaults.stringArray(forKey: orderKey) ?? [] } }

    public func windows(for provider: String) -> Set<String>? {
        lock.withLock {
            (defaults.dictionary(forKey: windowsKey) as? [String: [String]])?[provider].map(Set.init)
        }
    }

    public func setOrder(_ order: [String]) { lock.withLock { defaults.set(order, forKey: orderKey) } }

    public func setWindows(_ windows: Set<String>?, for provider: String) {
        lock.withLock {
            var stored = defaults.dictionary(forKey: windowsKey) as? [String: [String]] ?? [:]
            stored[provider] = windows.map { $0.sorted() }
            defaults.set(stored, forKey: windowsKey)
        }
    }
}
