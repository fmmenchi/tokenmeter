import Foundation

/// What the `tokenmeter` command prints (ADR 0017): the lines for a person and the JSON for a script, from the snapshot the app wrote
/// and the stats of the store. Pure functions: the command reads the files, these say what to print.
public enum CommandOutput {
    /// A reading older than this is printed with its age and the command exits `stale`.
    public static let freshFor: TimeInterval = 600

    public enum Exit: Int32, Sendable {
        case fresh = 0
        /// No snapshot: the app never ran on this Mac, or not as this user.
        case missing = 1
        case stale = 2
    }

    public static func exit(for snapshot: Snapshot?, now: Date) -> Exit {
        guard let snapshot else { return .missing }
        return now.timeIntervalSince(snapshot.generatedAt) > freshFor ? .stale : .fresh
    }

    /// "5 hours", "Weekly", and for a model's limit "Weekly · Fable".
    static func label(_ window: WindowSpec) -> String {
        let name = switch window.name {
        case "5h": "5 hours"
        case "7d": "Weekly"
        default: window.name
        }
        return ([name] + [window.scope].compactMap { $0 }).joined(separator: " · ")
    }

    /// "72% left", "~28% used", "unknown".
    static func figure(_ usage: WindowUsage, display: BarsDisplay, now: Date) -> String {
        guard let left = usage.remainingFraction else { return "unknown" }
        return "\(usage.isApproximate(at: now) ? "~" : "")\(display.figure(remaining: left))"
    }

    /// "just now", "4m ago", "3h ago", "2d ago".
    static func age(_ seconds: TimeInterval) -> String {
        switch max(seconds, 0) {
        case ..<60: "just now"
        case ..<3600: "\(Int(seconds / 60))m ago"
        case ..<86_400: "\(Int(seconds / 3600))h ago"
        default: "\(Int(seconds / 86_400))d ago"
        }
    }

    // MARK: The quota

    /// One block for each provider: its name and plan, then one line for each window, and the age of the reading at the end.
    public static func quotaText(_ snapshot: Snapshot, display: BarsDisplay, now: Date) -> String {
        var lines: [String] = []
        for provider in snapshot.providers {
            lines.append([provider.title, provider.plan.map { "(\($0))" }].compactMap { $0 }.joined(separator: " "))
            let rows = provider.windows.map { original -> (String, String, String) in
                let usage = provider.resolved(original, at: now)
                return (label(usage.window), figure(usage, display: display, now: now), usage.resetText(at: now).map { "resets \($0)" } ?? "")
            }
            let width = rows.map(\.0.count).max() ?? 0
            let figureWidth = rows.map(\.1.count).max() ?? 0
            for row in rows {
                let line = "  " + row.0.padding(toLength: width, withPad: " ", startingAt: 0) + "   "
                    + row.1.padding(toLength: figureWidth, withPad: " ", startingAt: 0) + (row.2.isEmpty ? "" : "   " + row.2)
                lines.append(line.trimmingTrailingSpaces())
            }
            if provider.windows.isEmpty, let hint = provider.setupHint { lines.append("  \(hint)") }
        }
        lines.append("Read \(age(now.timeIntervalSince(snapshot.generatedAt))).")
        return lines.joined(separator: "\n")
    }

    struct QuotaJSON: Encodable {
        struct Window: Encodable {
            let name: String
            let label: String
            let model: String?
            let left: Double?
            let used: Double?
            let figure: String
            let approximate: Bool
            let resetsAt: Date?
            let observedAt: Date?
            let tokens: Int
        }

        struct ProviderEntry: Encodable {
            let id: String
            let title: String
            let plan: String?
            let windows: [Window]
        }

        let version = 1
        let generatedAt: Date
        let ageSeconds: Int
        let stale: Bool
        let reading: String
        let providers: [ProviderEntry]
    }

    /// The snapshot as JSON, version 1: fields are added within a version, never renamed or removed (ADR 0017). Fractions are 0 to 1.
    public static func quotaJSON(_ snapshot: Snapshot, display: BarsDisplay, now: Date) throws -> Data {
        let providers = snapshot.providers.map { provider in
            QuotaJSON.ProviderEntry(id: provider.provider.rawValue, title: provider.title, plan: provider.plan,
                                    windows: provider.windows.map { original in
                let usage = provider.resolved(original, at: now)
                return QuotaJSON.Window(name: usage.window.name, label: label(usage.window), model: usage.window.scope,
                                        left: usage.remainingFraction, used: usage.remainingFraction.map { 1 - $0 },
                                        figure: figure(usage, display: display, now: now), approximate: usage.isApproximate(at: now),
                                        resetsAt: usage.resetsAt, observedAt: usage.observedAt,
                                        tokens: usage.tokens.input + usage.tokens.output)
            })
        }
        let ageSeconds = Int(now.timeIntervalSince(snapshot.generatedAt))
        return try encoder.encode(QuotaJSON(generatedAt: snapshot.generatedAt, ageSeconds: ageSeconds,
                                            stale: exit(for: snapshot, now: now) == .stale, reading: display.rawValue,
                                            providers: providers))
    }

    // MARK: The stats

    static func word(_ verdict: Verdict.Word) -> String {
        switch verdict {
        case .wait: "wait"
        case .stay: "stay"
        case .moveUp: "move up"
        case .moveDown: "move down"
        }
    }

    static func dollars(_ value: Double) -> String {
        value >= 100 ? "$\(Int(value.rounded()))" : String(format: "$%.2f", value)
    }

    /// For each provider: the suggestion, each window's summary, the models with their share and cost, and the total cost.
    public static func statsText(_ stats: [ProviderStats], titles: [Provider: String], range: StatsRange) -> String {
        var lines: [String] = []
        for provider in stats {
            lines.append("\(titles[provider.provider] ?? provider.provider.rawValue) · \(range.rawValue)")
            lines.append("  Suggestion: \(word(UsageStats.verdict(provider.windows).word))")
            for window in provider.windows {
                let name = window.name == "5h" ? "5 hours" : window.name == "7d" ? "Weekly" : window.name
                lines.append(window.closed == 0 ? "  \(name): not observed"
                    : "  \(name): reached 95% in \(window.hits) of \(window.closed)")
            }
            let models = provider.models.shown + provider.models.more + (provider.models.other.map { [$0] } ?? [])
            for model in models {
                let share = model.fraction < 0.01 ? "<1%" : "\(Int((model.fraction * 100).rounded()))%"
                lines.append("  \(model.name): \(model.tokens.compactCount) tokens, \(share)"
                    + (model.cost.map { ", ≈ \(dollars($0))" } ?? ""))
            }
            if let cost = provider.models.cost {
                lines.append("  At API list prices (\(Pricing.listedOn))\(provider.models.costIsPartial ? ", the models with a price" : ""): ≈ \(dollars(cost))")
            }
        }
        return lines.joined(separator: "\n")
    }

    struct StatsJSON: Encodable {
        struct Window: Encodable {
            let name: String
            let closed: Int
            let reachedCeiling: Int
        }

        struct Model: Encodable {
            let name: String
            let tokens: Int
            let share: Double
            let costUSD: Double?
        }

        struct ProviderEntry: Encodable {
            let id: String
            let title: String
            let suggestion: String
            let windows: [Window]
            let models: [Model]
            let costUSD: Double?
            let costIsPartial: Bool
        }

        let version = 1
        let range: String
        let pricesListedOn: String
        let providers: [ProviderEntry]
    }

    public static func statsJSON(_ stats: [ProviderStats], titles: [Provider: String], range: StatsRange) throws -> Data {
        let providers = stats.map { provider in
            let models = provider.models.shown + provider.models.more + (provider.models.other.map { [$0] } ?? [])
            return StatsJSON.ProviderEntry(
                id: provider.provider.rawValue, title: titles[provider.provider] ?? provider.provider.rawValue,
                suggestion: word(UsageStats.verdict(provider.windows).word),
                windows: provider.windows.map { StatsJSON.Window(name: $0.name, closed: $0.closed, reachedCeiling: $0.hits) },
                models: models.map { StatsJSON.Model(name: $0.name, tokens: $0.tokens, share: $0.fraction, costUSD: $0.cost) },
                costUSD: provider.models.cost, costIsPartial: provider.models.costIsPartial)
        }
        return try encoder.encode(StatsJSON(range: range.rawValue, pricesListedOn: Pricing.listedOn, providers: providers))
    }

    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

extension Int {
    /// 999, 14k, 1.2M: as the panel writes a count of tokens.
    var compactCount: String {
        switch self {
        case 1_000_000...: String(format: "%.1fM", Double(self) / 1_000_000)
        case 1_000...: String(format: "%.0fk", Double(self) / 1_000)
        default: String(self)
        }
    }
}

private extension String {
    func trimmingTrailingSpaces() -> String {
        var copy = self
        while copy.last == " " { copy.removeLast() }
        return copy
    }
}
