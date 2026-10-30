import Foundation

/// Which provider a reading belongs to: an id, so a new provider does not change this type.
/// Encoded as the bare string (`"claude"`), as the enum it replaced was.
public struct Provider: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(from decoder: any Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public static let claude = Provider(rawValue: "claude")
    public static let chatgpt = Provider(rawValue: "chatgpt")
}

public struct TokenCounts: Codable, Equatable, Sendable {
    public var input: Int
    public var output: Int
    public var cacheRead: Int
    public var cacheWrite: Int

    public init(input: Int = 0, output: Int = 0, cacheRead: Int = 0, cacheWrite: Int = 0) {
        self.input = input
        self.output = output
        self.cacheRead = cacheRead
        self.cacheWrite = cacheWrite
    }

    public var total: Int { input + output + cacheRead + cacheWrite }

    public static func + (lhs: Self, rhs: Self) -> Self {
        Self(input: lhs.input + rhs.input, output: lhs.output + rhs.output,
             cacheRead: lhs.cacheRead + rhs.cacheRead, cacheWrite: lhs.cacheWrite + rhs.cacheWrite)
    }
}

public struct UsageEvent: Equatable, Sendable {
    public let provider: Provider
    public let date: Date
    public let tokens: TokenCounts

    public init(provider: Provider, date: Date, tokens: TokenCounts) {
        self.provider = provider
        self.date = date
        self.tokens = tokens
    }
}

/// Quota reported by the provider itself, when a log carries it.
public struct ReportedQuota: Codable, Equatable, Sendable {
    public let usedPercent: Double
    public let windowMinutes: Int?
    public let resetsAt: Date?
    /// When the provider reported this value (not when it was read).
    public let observedAt: Date?
    /// The model this limit applies to, when it is not the provider's own (ADR 0034).
    public let scope: String?

    public init(usedPercent: Double, windowMinutes: Int?, resetsAt: Date?, observedAt: Date? = nil, scope: String? = nil) {
        self.scope = scope
        self.usedPercent = usedPercent
        self.windowMinutes = windowMinutes
        self.resetsAt = resetsAt
        self.observedAt = observedAt
    }
}
