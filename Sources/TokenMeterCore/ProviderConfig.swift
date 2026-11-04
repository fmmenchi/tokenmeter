import Foundation

/// The shape of `~/.tokenmeter/providers.json` (ADR 0003). Dotted paths and nothing else.
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

    /// Claude and ChatGPT as the file first holds them (ADR 0003). A starting point, never merged over
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

    /// The window that reads Claude's per-model limits from the usage copy Claude Code keeps (ADR 0002).
    static func claudeModelLimits() -> [String: Any] { [
        "file": "~/.claude.json", "each": "cachedUsageUtilization.utilization.limits",
        "where": ["kind": "weekly_scoped"], "scope": "scope.model.display_name", "minutes": 10080,
        "usedPercent": "percent", "resetsAt": "resets_at", "resetsAtFormat": "iso8601",
        "observedAt": "cachedUsageUtilization.fetchedAtMs", "observedAtFormat": "epochMilliseconds",
    ] }

    /// The rule that says Claude's 5-hour window exists only if the usage copy lists a session limit (ADR 0002).
    static func claudeFiveHourExists() -> [String: Any] {
        ["file": "~/.claude.json", "each": "cachedUsageUtilization.utilization.limits", "where": ["kind": "session"],
         "observedAt": "cachedUsageUtilization.fetchedAtMs", "observedAtFormat": "epochMilliseconds"]
    }

    /// Adds to the `claude` entry of an existing file what a newer version needs and the file lacks: its `integration`
    /// (ADR 0003), the window for its per-model limits (ADR 0002) and the rule for its 5 hours (ADR 0002); and to the
    /// `chatgpt` entry its `integration`, `codex` (ADR 0014). Each is added once and only when absent, and the original is
    /// kept as `.bak`.
    @discardableResult
    public static func addClaudeIntegration(to url: URL = defaultURL) -> MigrationOutcome {
        guard let data = try? Data(contentsOf: url),
              var object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              object["version"] as? Int == 1,
              var providers = object["providers"] as? [[String: Any]]
        else { return .untouched }
        var changed = false
        if let codex = providers.firstIndex(where: { $0["id"] as? String == "chatgpt" }), providers[codex]["integration"] == nil {
            providers[codex]["integration"] = "codex"
            changed = true
        }
        guard let index = providers.firstIndex(where: { $0["id"] as? String == "claude" }) else {
            return changed ? write(object, providers: providers, to: url) : .untouched
        }
        var entry = providers[index]
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
        return write(object, providers: providers, to: url)
    }

    /// The migrated file, with the original kept as `.bak`.
    private static func write(_ object: [String: Any], providers: [[String: Any]], to url: URL) -> MigrationOutcome {
        var object = object
        object["providers"] = providers
        let backup = url.appendingPathExtension("tokenmeter.bak")
        guard let output = try? JSONSerialization.data(
            withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]) else { return .untouched }
        try? FileManager.default.removeItem(at: backup)
        guard (try? FileManager.default.copyItem(at: url, to: backup)) != nil,
              (try? (output + Data("\n".utf8)).write(to: url, options: .atomic)) != nil else { return .untouched }
        return .migrated
    }

    /// Adds to the `usage` of Claude and ChatGPT in an existing file what the usage store needs and the file lacks: the path
    /// of the model's name and the rules that turn it into a family (ADR 0010). Each is added once and only when absent, so
    /// what the person wrote stays; the original is kept as `.bak`, as for the Claude integration.
    @discardableResult
    ///
    /// `keepingBackup` is for a run right after another migration of the same file: that one's `.bak` is the file as the person
    /// wrote it, and this one leaves it alone instead of replacing it with the file half migrated.
    public static func addUsageFacts(to url: URL = defaultURL, keepingBackup: Bool = false) -> MigrationOutcome {
        guard let data = try? Data(contentsOf: url),
              var object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              object["version"] as? Int == 1,
              var providers = object["providers"] as? [[String: Any]] else { return .untouched }
        var changed = false
        for (index, entry) in providers.enumerated() {
            guard let id = entry["id"] as? String else { continue }
            var updated = entry
            if let facts = DefaultProviders.usageFacts[id], var usage = entry["usage"] as? [String: Any] {
                if usage["model"] == nil, let model = facts.model {
                    usage["model"] = model
                    changed = true
                }
                if usage["families"] == nil {
                    usage["families"] = facts.families
                    changed = true
                }
                updated["usage"] = usage
            }
            if let context = DefaultProviders.logContext(for: id), var log = entry["log"] as? [String: Any], log["context"] == nil {
                log["context"] = context
                updated["log"] = log
                changed = true
            }
            providers[index] = updated
        }
        guard changed else { return .untouched }
        object["providers"] = providers
        let backup = url.appendingPathExtension("tokenmeter.bak")
        guard let output = try? JSONSerialization.data(
            withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]) else { return .untouched }
        if !(keepingBackup && FileManager.default.fileExists(atPath: backup.path)) {
            try? FileManager.default.removeItem(at: backup)
            guard (try? FileManager.default.copyItem(at: url, to: backup)) != nil else { return .untouched }
        }
        guard (try? (output + Data("\n".utf8)).write(to: url, options: .atomic)) != nil else { return .untouched }
        return .migrated
    }

    /// The entry for an account of `tool`: the seed entry with its paths rewritten for the folder and the id, explicit and
    /// readable by hand (ADR 0014). For the seed id and the default folder it is the seed entry itself, without `home`.
    public static func entry(for tool: AccountTool, id: String, title: String, home: String) -> [String: Any] {
        DefaultProviders.template(for: tool, id: id, title: title, home: home)
    }

    // MARK: The app writes whole entries (ADR 0014)

    /// An id made from a title, for an entry the app adds (ADR 0014): lower case, every run of other characters one `-`,
    /// nothing else; `account` when nothing is left, and a number when the id is taken.
    public static func id(for title: String, taken: Set<String>) -> String {
        var base = ""
        var gap = false
        for scalar in title.lowercased().unicodeScalars {
            if ProviderConfig.idCharacters.contains(scalar), scalar != "-" {
                if gap, !base.isEmpty { base.append("-") }
                base.unicodeScalars.append(scalar)
                gap = false
            } else {
                gap = true
            }
        }
        base = base.trimmingCharacters(in: CharacterSet(charactersIn: "._-"))
        if base.isEmpty { base = "account" }
        guard taken.contains(base) else { return base }
        var number = 2
        while taken.contains("\(base)-\(number)") { number += 1 }
        return "\(base)-\(number)"
    }

    /// Adds an entry to the file. The file is read as JSON, changed, kept as `.tokenmeter.bak` and written back atomically;
    /// nothing is written when the file cannot be used or the result would not load (a repeated id, say): the error says why.
    public static func add(_ entry: [String: Any], to url: URL = defaultURL) throws {
        var (object, providers) = try readForWriting(url)
        providers.append(entry)
        object["providers"] = providers
        try writeBack(object, to: url)
    }

    /// Replaces the entry with `id` by `entry`, in its place; the id must exist.
    public static func replace(_ id: String, with entry: [String: Any], in url: URL = defaultURL) throws {
        var (object, providers) = try readForWriting(url)
        guard let index = providers.firstIndex(where: { $0["id"] as? String == id }) else {
            throw Failure(description: "\(url.path): no provider \"\(id)\" to replace")
        }
        providers[index] = entry
        object["providers"] = providers
        try writeBack(object, to: url)
    }

    /// Removes the entry with `id`, and nothing else: the preferences, the history and the folder are not the file's.
    public static func remove(_ id: String, from url: URL = defaultURL) throws {
        var (object, providers) = try readForWriting(url)
        guard providers.contains(where: { $0["id"] as? String == id }) else {
            throw Failure(description: "\(url.path): no provider \"\(id)\" to remove")
        }
        providers.removeAll { $0["id"] as? String == id }
        object["providers"] = providers
        try writeBack(object, to: url)
    }

    /// `entry` with a new title and folder: a path is rewritten only where it still equals what the template gave for the
    /// old folder, so a path the person wrote by hand is left alone (ADR 0014). The id does not change.
    public static func edited(_ entry: [String: Any], tool: AccountTool, title: String, home: String) -> [String: Any] {
        guard let id = entry["id"] as? String else { return entry }
        let oldHome = entry["home"] as? String ?? tool.defaultHome
        var result = entry
        result["title"] = title
        guard home != oldHome else { return result }
        let before = DefaultProviders.template(for: tool, id: id, title: title, home: oldHome)
        let after = DefaultProviders.template(for: tool, id: id, title: title, home: home)
        result = moved(result, from: before, to: after) as! [String: Any]
        if home == tool.defaultHome { result["home"] = nil } else { result["home"] = home }
        return result
    }

    private static func moved(_ value: Any, from before: Any?, to after: Any?) -> Any {
        switch (value, before, after) {
        case let (object as [String: Any], old as [String: Any], new as [String: Any]):
            var result = object
            for (key, item) in object { result[key] = moved(item, from: old[key], to: new[key]) }
            return result
        case let (list as [Any], old as [Any], new as [Any]) where old.count == new.count:
            return list.enumerated().map { index, item in
                index < old.count ? moved(item, from: old[index], to: new[index]) : item
            }
        case let (path as String, old as String, new as String) where path == old:
            return new
        default:
            return value
        }
    }

    private static func readForWriting(_ url: URL) throws -> ([String: Any], [[String: Any]]) {
        guard let data = try? Data(contentsOf: url) else { throw Failure(description: "\(url.path): cannot be read") }
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              object["version"] as? Int == 1, let providers = object["providers"] as? [[String: Any]] else {
            throw Failure(description: "\(url.path): not a providers file the app can write")
        }
        return (object, providers)
    }

    /// Checks that the result loads, keeps the original as `.tokenmeter.bak`, then writes atomically, sorted keys.
    private static func writeBack(_ object: [String: Any], to url: URL) throws {
        let output = try JSONSerialization.data(
            withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        _ = try decode(output, origin: url.path)
        let backup = url.appendingPathExtension("tokenmeter.bak")
        try? FileManager.default.removeItem(at: backup)
        try FileManager.default.copyItem(at: url, to: backup)
        try (output + Data("\n".utf8)).write(to: url, options: .atomic)
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
            guard provider.id.unicodeScalars.allSatisfy(ProviderConfig.idCharacters.contains) else {
                throw Failure(description:
                    "\(origin): provider id \"\(provider.id)\" may use letters, digits, '.', '_' and '-' only: it names files")
            }
            guard !provider.windows.isEmpty, provider.windows.allSatisfy({ $0 > 0 }) else {
                throw Failure(description: "\(origin): \"\(provider.id)\" needs windows in minutes")
            }
        }
        return file
    }
}

/// A tool an account is a folder of (ADR 0014): which seed entry is its template, and which folder it reads by default.
public enum AccountTool: String, CaseIterable, Sendable {
    case claudeCode
    case codexCLI

    /// The id of the seed entry that is this tool's template.
    public var seedID: String {
        switch self {
        case .claudeCode: "claude"
        case .codexCLI: "chatgpt"
        }
    }

    /// The folder the tool reads when nothing points it elsewhere.
    public var defaultHome: String {
        switch self {
        case .claudeCode: "~/.claude"
        case .codexCLI: "~/.codex"
        }
    }

    public var name: String {
        switch self {
        case .claudeCode: "Claude Code"
        case .codexCLI: "Codex CLI"
        }
    }
}

public struct ProviderConfig: Decodable, Sendable {
    /// Names the entry everywhere, and files on disk too (the status line's), so it is letters, digits, `.`, `_` and `-`
    /// (ADR 0014).
    public let id: String
    public let title: String
    public let windows: [Int]
    public let setupHint: String?
    /// The folder the tool reads, the one `CLAUDE_CONFIG_DIR` or `CODEX_HOME` would name, with `~` the person's home; nil
    /// means the tool's default folder. It serves the integration: the other paths of the entry stay as written (ADR 0014).
    public let home: String?
    /// The id of the integration that reports this provider's problems and fixes them (ADR 0005); nil when it has none.
    public let integration: String?
    public let log: Log?
    public let usage: Usage?
    public let quota: Quota?
    public let plan: Plan?

    /// What an id may be made of: it names files on disk (ADR 0014).
    static let idCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")

    public struct Log: Decodable, Sendable {
        public let root: String
        /// Cheap byte filter applied before a line is decoded.
        public let contains: String?
        /// Paths that must equal these strings for a line to count.
        public let `where`: [String: String]?
        /// ISO 8601 timestamp path.
        public let timestamp: String
        /// A line that says which model the lines after it belong to, as Codex does at the start of each turn (ADR 0010).
        public let context: Context?

        public struct Context: Decodable, Sendable {
            /// Cheap byte filter, as `Log.contains`.
            public let contains: String
            public let `where`: [String: String]?
            /// The path of the model's name in the line.
            public let model: String
        }
    }

    public struct Usage: Decodable, Sendable {
        public enum Mode: String, Decodable, Sendable { case perEvent, cumulative }
        public let mode: Mode
        public let dedupeBy: [String]?
        public let tokens: Tokens
        /// The path of the model's name in a line, so the tokens can be told apart by model (ADR 0010).
        public let model: String?
        /// Ordered rules that turn a model's name into the family it is shown as; the first that matches wins, and a name
        /// that matches none is shown as it is (ADR 0010).
        public let families: [Family]?

        public struct Family: Decodable, Sendable, Equatable {
            /// A fragment of the model's name, compared without case.
            public let contains: String
            public let family: String

            public init(contains: String, family: String) {
                self.contains = contains
                self.family = family
            }
        }
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
            /// the entry (ADR 0002). Without it the window is the one object at `at`.
            public let each: String?
            /// Fields an entry of `each` must equal, by path inside the entry.
            public let `where`: [String: String]?
            /// With `each`, the path inside an entry of what the limit applies to, such as a model's name.
            public let scope: String?
            /// Where the file says when its figures were fetched, from the file's root; the file's age when absent.
            public let observedAt: String?
            public let observedAtFormat: TimeFormat?
            /// The window exists only if a list names it (ADR 0002); without it the window is always there.
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
    /// it is fresh (`maxAgeHours`, 6 by default); otherwise nothing is said and the window stays (ADR 0002).
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
