import Foundation

/// What a provider is: constants it declares once (ADR 0015).
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

/// What a provider's files say right now.
public struct ProviderReading: Sendable {
    public var events: [UsageEvent]
    public var quotas: [ReportedQuota]
    public var plan: String?
    /// When the provider last wrote its quota; nil if it never did.
    public var quotaUpdatedAt: Date?
    /// Lengths in minutes of windows the plan does not have, when fresh data says so (ADR 0037).
    public var absent: Set<Int>

    public init(events: [UsageEvent] = [], quotas: [ReportedQuota] = [], plan: String? = nil,
                quotaUpdatedAt: Date? = nil, absent: Set<Int> = []) {
        self.absent = absent
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
