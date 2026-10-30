import Foundation

/// How the person wants the providers shown: the order of the cards, which windows of each have a row (ADR 0035) and
/// which providers are hidden (ADR 0036).
/// Preferences of the app, keyed by provider id; `providers.json` is never written for them.
public protocol DisplayPreferences: Sendable {
    /// Provider ids, first card first. A provider not in the list comes after the ones that are.
    var order: [String] { get }
    /// The windows (by name) shown for a provider; nil means every window.
    func windows(for provider: String) -> Set<String>?
    /// Provider ids whose card is not shown. A hidden provider keeps its place in the order and its choice of windows.
    var hidden: Set<String> { get }
    func setOrder(_ order: [String])
    func setHidden(_ hidden: Bool, for provider: String)
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
    private var storedHidden: Set<String> = []

    public init() {}

    public var hidden: Set<String> { lock.withLock { storedHidden } }

    public func setHidden(_ hidden: Bool, for provider: String) {
        lock.withLock { if hidden { storedHidden.insert(provider) } else { storedHidden.remove(provider) } }
    }

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
    private let hiddenKey: String
    private let lock = NSLock()

    public init(defaults: UserDefaults = .standard, orderKey: String = "providerOrder",
                windowsKey: String = "providerWindows", hiddenKey: String = "hiddenProviders") {
        self.defaults = defaults
        self.orderKey = orderKey
        self.windowsKey = windowsKey
        self.hiddenKey = hiddenKey
    }

    public var hidden: Set<String> { lock.withLock { Set(defaults.stringArray(forKey: hiddenKey) ?? []) } }

    public func setHidden(_ hidden: Bool, for provider: String) {
        lock.withLock {
            var ids = Set(defaults.stringArray(forKey: hiddenKey) ?? [])
            if hidden { ids.insert(provider) } else { ids.remove(provider) }
            defaults.set(ids.sorted(), forKey: hiddenKey)
        }
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
