import Foundation

/// The shape of `~/.tokenmeter/providers.json` (ADR 0016). Dotted paths and nothing else.
public struct ProviderConfigFile: Decodable, Sendable {
    public let version: Int
    public let providers: [ProviderConfig]

    public static let defaultURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".tokenmeter/providers.json")

    public struct Failure: Error, CustomStringConvertible {
        public let description: String
    }

    /// Nil when the file does not exist; throws when it exists but cannot be used.
    public static func load(from url: URL = defaultURL) throws -> ProviderConfigFile? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try decode(Data(contentsOf: url), origin: url.path)
    }

    /// Claude and ChatGPT as the file first holds them (ADR 0018). A starting point, never merged over
    /// what the user has.
    public static func seed() -> ProviderConfigFile {
        // A constant checked by a test: failing here is a bug in the app, not a user error.
        try! decode(Data(DefaultProviders.json.utf8), origin: "seed providers")
    }

    /// Creates the file from the seed; an existing file is left alone.
    @discardableResult
    public static func writeSeed(to url: URL = defaultURL) -> Bool {
        guard !FileManager.default.fileExists(atPath: url.path) else { return false }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        return (try? Data((DefaultProviders.json + "\n").utf8).write(to: url, options: .withoutOverwriting)) != nil
    }

    public enum MigrationOutcome: Equatable, Sendable {
        case migrated
        /// Nothing to add, or the file is not one this rule applies to; it was left as it is.
        case untouched
    }

    /// The window that reads Claude's per-model limits from the usage copy Claude Code keeps (ADR 0034).
    static func claudeModelLimits() -> [String: Any] { [
        "file": "~/.claude.json", "each": "cachedUsageUtilization.utilization.limits",
        "where": ["kind": "weekly_scoped"], "scope": "scope.model.display_name", "minutes": 10080,
        "usedPercent": "percent", "resetsAt": "resets_at", "resetsAtFormat": "iso8601",
        "observedAt": "cachedUsageUtilization.fetchedAtMs", "observedAtFormat": "epochMilliseconds",
    ] }

    /// The rule that says Claude's 5-hour window exists only if the usage copy lists a session limit (ADR 0037).
    static func claudeFiveHourExists() -> [String: Any] {
        ["file": "~/.claude.json", "each": "cachedUsageUtilization.utilization.limits", "where": ["kind": "session"],
         "observedAt": "cachedUsageUtilization.fetchedAtMs", "observedAtFormat": "epochMilliseconds"]
    }

    /// Adds to the `claude` entry of an existing file what a newer version needs and the file lacks: its `integration`
    /// (ADR 0033), the window for its per-model limits (ADR 0034) and the rule for its 5 hours (ADR 0037). The only changes the app makes to a file that is
    /// already there; each is added once and only when absent, and the original is kept as `.bak`.
    @discardableResult
    public static func addClaudeIntegration(to url: URL = defaultURL) -> MigrationOutcome {
        guard let data = try? Data(contentsOf: url),
              var object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              object["version"] as? Int == 1,
              var providers = object["providers"] as? [[String: Any]],
              let index = providers.firstIndex(where: { $0["id"] as? String == "claude" })
        else { return .untouched }
        var entry = providers[index]
        var changed = false
        if entry["integration"] == nil {
            entry["integration"] = "claude-status-line"
            changed = true
        }
        if var quota = entry["quota"] as? [String: Any], var windows = quota["windows"] as? [[String: Any]] {
            if !windows.contains(where: { $0["each"] != nil }) {
                windows.append(claudeModelLimits())
                changed = true
            }
            if let five = windows.firstIndex(where: { ($0["at"] as? String) == "rate_limits.five_hour" && $0["existsIf"] == nil }) {
                windows[five]["existsIf"] = claudeFiveHourExists()
                changed = true
            }
            quota["windows"] = windows
            entry["quota"] = quota
        }
        // Anthropic renamed Max 20x to Ultra: the rule that carries the old default text gets the new one. A label the person
        // wrote themselves is left alone.
        if var plan = entry["plan"] as? [String: Any], var labels = plan["labels"] as? [[String: Any]],
           let rule = labels.firstIndex(where: { ($0["contains"] as? String) == "max_20x" && ($0["label"] as? String) == "Max 20x" }) {
            labels[rule]["label"] = "Ultra"
            plan["labels"] = labels
            entry["plan"] = plan
            changed = true
        }
        guard changed else { return .untouched }
        providers[index] = entry
        object["providers"] = providers
        let backup = url.appendingPathExtension("tokenmeter.bak")
        guard let output = try? JSONSerialization.data(
            withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]) else { return .untouched }
        try? FileManager.default.removeItem(at: backup)
        guard (try? FileManager.default.copyItem(at: url, to: backup)) != nil,
              (try? (output + Data("\n".utf8)).write(to: url, options: .atomic)) != nil else { return .untouched }
        return .migrated
    }

    static func decode(_ data: Data, origin: String) throws -> ProviderConfigFile {
        let file: ProviderConfigFile
        do {
            file = try JSONDecoder().decode(ProviderConfigFile.self, from: data)
        } catch {
            throw Failure(description: "\(origin): \(error)")
        }
        guard file.version == 1 else { throw Failure(description: "\(origin): unsupported version \(file.version)") }
        var seen = Set<String>()
        for provider in file.providers {
            guard !provider.id.isEmpty, seen.insert(provider.id).inserted else {
                throw Failure(description: "\(origin): provider id \"\(provider.id)\" is empty or repeated")
            }
            guard !provider.windows.isEmpty, provider.windows.allSatisfy({ $0 > 0 }) else {
                throw Failure(description: "\(origin): \"\(provider.id)\" needs windows in minutes")
            }
        }
        return file
    }
}

public struct ProviderConfig: Decodable, Sendable {
    public let id: String
    public let title: String
    public let windows: [Int]
    public let setupHint: String?
    /// The id of the integration that reports this provider's problems and fixes them (ADR 0031); nil when it has none.
    public let integration: String?
    public let log: Log?
    public let usage: Usage?
    public let quota: Quota?
    public let plan: Plan?

    public struct Log: Decodable, Sendable {
        public let root: String
        /// Cheap byte filter applied before a line is decoded.
        public let contains: String?
        /// Paths that must equal these strings for a line to count.
        public let `where`: [String: String]?
        /// ISO 8601 timestamp path.
        public let timestamp: String
    }

    public struct Usage: Decodable, Sendable {
        public enum Mode: String, Decodable, Sendable { case perEvent, cumulative }
        public let mode: Mode
        public let dedupeBy: [String]?
        public let tokens: Tokens
    }

    public struct Tokens: Decodable, Sendable {
        public let input: Field?
        public let output: Field?
        public let cacheRead: Field?
        public let cacheWrite: Field?
    }

    /// A path, or `{ "path": …, "minus": … }` for a difference.
    public struct Field: Decodable, Sendable {
        public let path: String
        public let minus: String?

        public init(from decoder: any Decoder) throws {
            if let path = try? decoder.singleValueContainer().decode(String.self) {
                self.path = path
                minus = nil
            } else {
                let keyed = try decoder.container(keyedBy: Keys.self)
                path = try keyed.decode(String.self, forKey: .path)
                minus = try keyed.decodeIfPresent(String.self, forKey: .minus)
            }
        }

        private enum Keys: String, CodingKey { case path, minus }
    }

    public struct Quota: Decodable, Sendable {
        public let file: String?
        public let windows: [Window]

        public struct Window: Decodable, Sendable {
            public enum TimeFormat: String, Decodable, Sendable { case epochSeconds, epochMilliseconds, iso8601 }
            /// A file of its own for this window, instead of the quota's.
            public let file: String?
            /// A path to a list of limits: one window for each entry that matches `where`, with the paths below read inside
            /// the entry (ADR 0034). Without it the window is the one object at `at`.
            public let each: String?
            /// Fields an entry of `each` must equal, by path inside the entry.
            public let `where`: [String: String]?
            /// With `each`, the path inside an entry of what the limit applies to, such as a model's name.
            public let scope: String?
            /// Where the file says when its figures were fetched, from the file's root; the file's age when absent.
            public let observedAt: String?
            public let observedAtFormat: TimeFormat?
            /// The window exists only if a list names it (ADR 0037); without it the window is always there.
            public let existsIf: ExistsIf?
            /// The object holding the fields below; the line or file root when absent.
            public let at: String?
            public let usedPercent: String
            public let resetsAt: String?
            public let resetsAtFormat: TimeFormat?
            public let minutes: Int?
            public let minutesPath: String?
        }
    }

    /// A list that says whether a window exists: one entry of `each` must match `where`. The list is believed only while
    /// it is fresh (`maxAgeHours`, 6 by default); otherwise nothing is said and the window stays (ADR 0037).
    public struct ExistsIf: Decodable, Sendable {
        public let file: String
        public let each: String
        public let `where`: [String: String]?
        public let observedAt: String?
        public let observedAtFormat: Quota.Window.TimeFormat?
        public let maxAgeHours: Double?
    }

    public struct Plan: Decodable, Sendable {
        public let file: String?
        public let path: String
        /// Removed from the start of the raw value before it is capitalised.
        public let stripPrefix: String?
        /// Ordered rules; the first match wins. With none, the raw value is capitalised.
        public let labels: [Label]?

        public struct Label: Decodable, Sendable {
            /// Where to look; the plan's own `path` when absent.
            public let path: String?
            public let contains: String?
            public let equals: String?
            public let label: String
        }
    }
}
