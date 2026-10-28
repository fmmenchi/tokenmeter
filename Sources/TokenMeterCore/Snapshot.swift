import Foundation

public struct WindowSpec: Codable, Equatable, Sendable {
    public let name: String
    public let duration: TimeInterval
    /// User-configured token budget for the window. Plan limits are not published in tokens,
    /// so a nil limit means "unknown": only consumption is shown, never a remaining quota.
    public let tokenLimit: Int?

    public init(name: String, duration: TimeInterval, tokenLimit: Int?) {
        self.name = name
        self.duration = duration
        self.tokenLimit = tokenLimit
    }

    public static let session = WindowSpec(name: "5h", duration: 5 * 3600, tokenLimit: nil)
    public static let week = WindowSpec(name: "7d", duration: 7 * 24 * 3600, tokenLimit: nil)
}

public struct WindowUsage: Codable, Equatable, Sendable {
    public enum Source: String, Codable, Sendable {
        /// Percentage reported by the provider in its own logs.
        case reported
        /// Consumed tokens against a user-configured limit.
        case estimated
        /// Consumption only; no remaining quota can be stated.
        case consumptionOnly
    }

    public let window: WindowSpec
    public let tokens: TokenCounts
    /// 0...1 when known.
    public let remainingFraction: Double?
    public let source: Source
    public let resetsAt: Date?
}

public struct ProviderSnapshot: Codable, Equatable, Sendable {
    public let provider: Provider
    public let windows: [WindowUsage]
}

public struct Snapshot: Codable, Equatable, Sendable {
    public let generatedAt: Date
    public let providers: [ProviderSnapshot]
    /// When the Claude status line last wrote its quota; nil if it never did.
    public let claudeQuotaUpdatedAt: Date?

    public init(generatedAt: Date, providers: [ProviderSnapshot], claudeQuotaUpdatedAt: Date? = nil) {
        self.generatedAt = generatedAt
        self.providers = providers
        self.claudeQuotaUpdatedAt = claudeQuotaUpdatedAt
    }
}

public enum SnapshotBuilder {
    public static func providerSnapshot(
        provider: Provider,
        events: [UsageEvent],
        windows: [WindowSpec],
        reported: [ReportedQuota] = [],
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
                                   source: .reported, resetsAt: reported.resetsAt)
            }
            if let limit = spec.tokenLimit, limit > 0 {
                return WindowUsage(window: spec, tokens: tokens,
                                   remainingFraction: max(0, 1 - Double(tokens.total) / Double(limit)),
                                   source: .estimated, resetsAt: nil)
            }
            return WindowUsage(window: spec, tokens: tokens, remainingFraction: nil,
                               source: .consumptionOnly, resetsAt: nil)
        }
        return ProviderSnapshot(provider: provider, windows: usages)
    }
}
