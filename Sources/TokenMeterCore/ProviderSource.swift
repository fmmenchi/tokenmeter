import Foundation

/// What a provider is: constants it declares once (ADR 0003).
public struct ProviderInfo: Sendable {
    public let provider: Provider
    public let title: String
    public let windows: [WindowSpec]
    /// Shown while no quota has been seen, e.g. how to turn the quota on.
    public let setupHint: String?

    public init(provider: Provider, title: String, windows: [WindowSpec], setupHint: String? = nil) {
        self.provider = provider
        self.title = title
        self.windows = windows
        self.setupHint = setupHint
    }
}

/// The highest percentage a log reported for one window, from when it was first to when it was last seen (ADR 0010).
public struct WindowReading: Equatable, Sendable {
    public let windowMinutes: Int
    public let resetsAt: Date
    public let usedPercent: Double
    public let firstObserved: Date
    public let lastObserved: Date

    public init(windowMinutes: Int, resetsAt: Date, usedPercent: Double, firstObserved: Date, lastObserved: Date) {
        self.windowMinutes = windowMinutes
        self.resetsAt = resetsAt
        self.usedPercent = usedPercent
        self.firstObserved = firstObserved
        self.lastObserved = lastObserved
    }
}

/// What a provider's files say right now.
public struct ProviderReading: Sendable {
    public var events: [UsageEvent]
    public var quotas: [ReportedQuota]
    /// Every window a log reported, not only the last reading of each length: what `quotas` forgets.
    public var history: [WindowReading]
    public var plan: String?
    /// When the provider last wrote its quota; nil if it never did.
    public var quotaUpdatedAt: Date?
    /// Lengths in minutes of windows the plan does not have, when fresh data says so (ADR 0002).
    public var absent: Set<Int>

    public init(events: [UsageEvent] = [], quotas: [ReportedQuota] = [], history: [WindowReading] = [], plan: String? = nil,
                quotaUpdatedAt: Date? = nil, absent: Set<Int> = []) {
        self.absent = absent
        self.history = history
        self.events = events
        self.quotas = quotas
        self.plan = plan
        self.quotaUpdatedAt = quotaUpdatedAt
    }
}

/// The contract every provider implements. Window maths, bars and refresh are common and not here.
public protocol ProviderSource: Sendable {
    var info: ProviderInfo { get }
    func read(since: Date) -> ProviderReading
}
