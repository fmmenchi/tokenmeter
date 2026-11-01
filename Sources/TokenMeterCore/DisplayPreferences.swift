import Foundation

/// How the person wants the providers shown: the order of the cards, which windows of each have a row (ADR 0035) and
/// which providers are hidden (ADR 0036).
/// Preferences of the app, keyed by provider id; `providers.json` is never written for them.
public protocol DisplayPreferences: Sendable {
    /// Provider ids, first card first. A provider not in the list comes after the ones that are.
    var order: [String] { get }
    /// The windows (by name) shown for a provider; nil means every window.
    func windows(for provider: String) -> Set<String>?
    /// The models of a provider the person turned off, by window id. A model is on unless it is here, so one that appears
    /// later, when a plan gains it, shows up (ADR 0037).
    func hiddenModels(for provider: String) -> Set<String>
    func setHiddenModels(_ models: Set<String>, for provider: String)
    /// Provider ids whose card is not shown. A hidden provider keeps its place in the order and its choice of windows.
    var hidden: Set<String> { get }
    func setOrder(_ order: [String])
    func setHidden(_ hidden: Bool, for provider: String)
    func setWindows(_ windows: Set<String>?, for provider: String)
}

/// A provider's windows as Settings shows them: its own windows, and the models that are part of one of them.
public struct WindowChoice: Sendable {
    public let windows: [String]
    /// Model window id to the id of the window it is part of.
    public let models: [String: String]

    public init(windows: [String], models: [String: String]) {
        self.windows = windows
        self.models = models
    }
}

extension DisplayPreferences {
    /// The person chooses windows in Settings (ADR 0041). A window turned off never hides the provider: the provider's own
    /// switch does that, so an empty choice is refused and the last window stays on. A window that was just selected turns
    /// its models on, as they are by default. Returns false when the choice was refused.
    @discardableResult
    public func select(_ windows: Set<String>, among choice: WindowChoice, for provider: String) -> Bool {
        let all = Set(choice.windows)
        let selected = windows.intersection(all)
        guard !selected.isEmpty else { return false }
        let before = (self.windows(for: provider)?.intersection(all)).flatMap { $0.isEmpty ? nil : $0 } ?? all
        let added = selected.subtracting(before)
        var off = hiddenModels(for: provider)
        for (model, parent) in choice.models where added.contains(parent) { off.remove(model) }
        setHiddenModels(off, for: provider)
        setWindows(selected == all ? nil : selected, for: provider)
        return true
    }

    /// Shows or hides a provider with its switch. Neither touches its windows or its models: a provider that is shown again
    /// comes back as it was (ADR 0041).
    public func setShown(_ shown: Bool, for provider: String) {
        setHidden(!shown, for: provider)
    }

    /// Turns a model on or off.
    public func setModel(_ model: String, shown: Bool, for provider: String) {
        var off = hiddenModels(for: provider)
        if shown { off.remove(model) } else { off.insert(model) }
        setHiddenModels(off, for: provider)
    }

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
    private var storedModels: [String: Set<String>] = [:]

    public init() {}

    public var hidden: Set<String> { lock.withLock { storedHidden } }

    public func setHidden(_ hidden: Bool, for provider: String) {
        lock.withLock { if hidden { storedHidden.insert(provider) } else { storedHidden.remove(provider) } }
    }

    public func hiddenModels(for provider: String) -> Set<String> { lock.withLock { storedModels[provider] ?? [] } }

    public func setHiddenModels(_ models: Set<String>, for provider: String) {
        lock.withLock { storedModels[provider] = models.isEmpty ? nil : models }
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
    private let modelsKey: String
    private let lock = NSLock()

    public init(defaults: UserDefaults = .standard, orderKey: String = "providerOrder",
                windowsKey: String = "providerWindows", hiddenKey: String = "hiddenProviders",
                modelsKey: String = "hiddenModels") {
        self.defaults = defaults
        self.orderKey = orderKey
        self.windowsKey = windowsKey
        self.hiddenKey = hiddenKey
        self.modelsKey = modelsKey
    }

    public var hidden: Set<String> { lock.withLock { Set(defaults.stringArray(forKey: hiddenKey) ?? []) } }

    public func hiddenModels(for provider: String) -> Set<String> {
        lock.withLock { (defaults.dictionary(forKey: modelsKey) as? [String: [String]])?[provider].map(Set.init) ?? [] }
    }

    public func setHiddenModels(_ models: Set<String>, for provider: String) {
        lock.withLock {
            var stored = defaults.dictionary(forKey: modelsKey) as? [String: [String]] ?? [:]
            stored[provider] = models.isEmpty ? nil : models.sorted()
            defaults.set(stored, forKey: modelsKey)
        }
    }

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
