import Foundation

public struct WindowSpec: Codable, Equatable, Sendable {
    public let name: String
    public let duration: TimeInterval

    public init(name: String, duration: TimeInterval) {
        self.name = name
        self.duration = duration
    }

    public static let session = WindowSpec(name: "5h", duration: 5 * 3600)
    public static let week = WindowSpec(name: "7d", duration: 7 * 24 * 3600)
}

public struct WindowUsage: Codable, Equatable, Sendable {
    public enum Source: String, Codable, Sendable {
        /// Percentage reported by the provider in its own logs.
        case reported
        /// The last reported window has expired and nothing was used since: it is full again.
        /// Inferred, not reported (ADR 0007).
        case reset
        /// Consumption only; no remaining quota can be stated.
        case consumptionOnly
    }

    public let window: WindowSpec
    public let tokens: TokenCounts
    /// 0...1 when known.
    public let remainingFraction: Double?
    public let source: Source
    public let resetsAt: Date?
    /// When the provider last reported the figure behind `remainingFraction`; nil if not reported.
    public let observedAt: Date?

    public init(window: WindowSpec, tokens: TokenCounts, remainingFraction: Double?, source: Source,
                resetsAt: Date?, observedAt: Date?) {
        self.window = window
        self.tokens = tokens
        self.remainingFraction = remainingFraction
        self.source = source
        self.resetsAt = resetsAt
        self.observedAt = observedAt
    }

    /// The window as it reads at `now`. A reported figure whose reset time has
    /// passed is no longer valid, however old the snapshot: it reads as reset (ADR 0007/0008).
    public func resolved(at now: Date) -> WindowUsage {
        guard source == .reported, let resetsAt, resetsAt <= now else { return self }
        return WindowUsage(window: window, tokens: tokens, remainingFraction: 1, source: .reset,
                           resetsAt: nil, observedAt: nil)
    }
}

public struct ProviderSnapshot: Codable, Equatable, Sendable {
    public let provider: Provider
    /// Display name; falls back to the provider id for a snapshot written before it existed.
    public let title: String
    public let windows: [WindowUsage]
    /// Subscription label such as "Max 20x"; nil when the CLI recorded none (ADR 0012).
    public let plan: String?
    /// When the provider's quota was last written; nil if it never was.
    public let quotaUpdatedAt: Date?
    /// Shown while no quota has been seen; nil when the provider has nothing to set up (ADR 0015).
    public let setupHint: String?

    public init(provider: Provider, title: String? = nil, windows: [WindowUsage], plan: String? = nil,
                quotaUpdatedAt: Date? = nil, setupHint: String? = nil) {
        self.provider = provider
        self.title = title ?? provider.rawValue
        self.windows = windows
        self.plan = plan
        self.quotaUpdatedAt = quotaUpdatedAt
        self.setupHint = setupHint
    }

    private enum CodingKeys: String, CodingKey {
        case provider, title, windows, plan, quotaUpdatedAt, setupHint
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let provider = try c.decode(Provider.self, forKey: .provider)
        self.init(provider: provider, title: try c.decodeIfPresent(String.self, forKey: .title),
                  windows: try c.decode([WindowUsage].self, forKey: .windows),
                  plan: try c.decodeIfPresent(String.self, forKey: .plan),
                  quotaUpdatedAt: try c.decodeIfPresent(Date.self, forKey: .quotaUpdatedAt),
                  setupHint: try c.decodeIfPresent(String.self, forKey: .setupHint))
    }
}

public struct Snapshot: Codable, Equatable, Sendable {
    public let generatedAt: Date
    public let providers: [ProviderSnapshot]
    /// Sentences for the person looking at the widget or the panel; written by the app, not the collector (ADR 0027).
    /// Replaced by `problems` (ADR 0030).
    public let notices: [String]
    /// What the person should know about, visible ones only; written by the app, not the collector (ADR 0030).
    public let problems: [Problem]

    public init(generatedAt: Date, providers: [ProviderSnapshot], notices: [String] = [], problems: [Problem] = []) {
        self.generatedAt = generatedAt
        self.providers = providers
        self.notices = notices
        self.problems = problems
    }

    private enum CodingKeys: String, CodingKey { case generatedAt, providers, notices, problems }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(generatedAt: try c.decode(Date.self, forKey: .generatedAt),
                  providers: try c.decode([ProviderSnapshot].self, forKey: .providers),
                  notices: try c.decodeIfPresent([String].self, forKey: .notices) ?? [],
                  problems: try c.decodeIfPresent([Problem].self, forKey: .problems) ?? [])
    }

    public func with(notices: [String]) -> Snapshot {
        Snapshot(generatedAt: generatedAt, providers: providers, notices: notices, problems: problems)
    }

    public func with(problems: [Problem]) -> Snapshot {
        Snapshot(generatedAt: generatedAt, providers: providers, notices: notices, problems: problems)
    }
}

public enum SnapshotBuilder {
    public static func providerSnapshot(
        provider: Provider,
        title: String? = nil,
        events: [UsageEvent],
        windows: [WindowSpec],
        reported: [ReportedQuota] = [],
        plan: String? = nil,
        quotaUpdatedAt: Date? = nil,
        setupHint: String? = nil,
        now: Date = Date()
    ) -> ProviderSnapshot {
        let usages = windows.map { spec -> WindowUsage in
            let start = now.addingTimeInterval(-spec.duration)
            let tokens = events.lazy.filter { $0.date >= start && $0.date <= now }
                .reduce(TokenCounts()) { $0 + $1.tokens }

            if let reported = reported.first(where: {
                guard let minutes = $0.windowMinutes, abs(Double(minutes) * 60 - spec.duration) < 60 else { return false }
                return $0.resetsAt.map { $0 > now } ?? true
            }) {
                return WindowUsage(window: spec, tokens: tokens,
                                   remainingFraction: max(0, 1 - reported.usedPercent / 100),
                                   source: .reported, resetsAt: reported.resetsAt, observedAt: reported.observedAt)
            }
            if tokens.total == 0, reported.contains(where: {
                guard let minutes = $0.windowMinutes, abs(Double(minutes) * 60 - spec.duration) < 60 else { return false }
                return $0.resetsAt.map { $0 <= now } ?? false
            }) {
                return WindowUsage(window: spec, tokens: tokens, remainingFraction: 1,
                                   source: .reset, resetsAt: nil, observedAt: nil)
            }
            return WindowUsage(window: spec, tokens: tokens, remainingFraction: nil,
                               source: .consumptionOnly, resetsAt: nil, observedAt: nil)
        }
        return ProviderSnapshot(provider: provider, title: title, windows: usages, plan: plan,
                                quotaUpdatedAt: quotaUpdatedAt, setupHint: setupHint)
    }
}
