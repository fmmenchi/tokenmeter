import Foundation

/// Sets up the Claude Code status line that leaves the quota on disk (ADR 0002, 0004), for one account at a time: the folder
/// Claude Code reads, and the entry's id that names the files (ADR 0014).
/// It never replaces a status line someone else set, and never touches a settings file it cannot read.
public enum ClaudeStatusLine {
    /// A Claude account as the status line sees it: the entry's id, and the folder Claude Code reads for it.
    public struct Account: Equatable, Sendable {
        public let id: String
        public let configDir: URL

        public init(id: String, configDir: URL) {
            self.id = id
            self.configDir = configDir
        }

        /// The seed entry in the default folder: what the app set up before accounts existed.
        public static func `default`(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> Account {
            Account(id: AccountTool.claudeCode.seedID, configDir: home.appendingPathComponent(".claude"))
        }
    }

    public enum Outcome: Equatable, Sendable {
        /// No folder for Claude Code: nothing was created.
        case notInstalled
        case set
        case alreadySet
        /// Another status line was wrapped, so both it and tokenmeter's script get the input (ADR 0004).
        case wrapped
        /// Another status line is in use; it was left alone. Carries its command.
        case otherStatusLine(String)
        /// `settings.json` could not be read as a JSON object; it was left alone.
        case unreadableSettings
    }

    /// The one copy of the script, shared by every account.
    static func scriptURL(home: URL) -> URL { home.appendingPathComponent(".tokenmeter/claude-statusline.sh") }

    /// The command written into the account's `settings.json`: the script, with the entry's id as its argument so it writes
    /// a file of its own; the seed entry's command has no argument, byte for byte as before accounts (ADR 0014).
    static func command(for account: Account, home: URL) -> String {
        let script = scriptURL(home: home).path
        return account.id == AccountTool.claudeCode.seedID ? script : "\(script) \(account.id)"
    }

    static func wrapperURL(for account: Account, home: URL) -> URL {
        home.appendingPathComponent(".tokenmeter/\(account.id)/statusline-wrapper.sh")
    }

    private static func originalURL(for account: Account, home: URL) -> URL {
        home.appendingPathComponent(".tokenmeter/\(account.id)/original-statusline.json")
    }

    /// Whether `command` is tokenmeter's own for this account: its script, with or without the argument, or its wrapper.
    private static func isOwn(_ command: String, account: Account, home: URL) -> Bool {
        [scriptURL(home: home).path, self.command(for: account, home: home), wrapperURL(for: account, home: home).path]
            .contains(command)
    }

    public static func setUp(script: Data, home: URL = FileManager.default.homeDirectoryForCurrentUser) throws -> Outcome {
        try setUp(script: script, account: .default(home: home), home: home)
    }

    /// Sets the status line up in the account's folder. `home` is where tokenmeter keeps its own files.
    public static func setUp(script: Data, account: Account,
                             home: URL = FileManager.default.homeDirectoryForCurrentUser) throws -> Outcome {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: account.configDir.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return .notInstalled
        }

        let command = scriptURL(home: home)
        try fileManager.createDirectory(at: command.deletingLastPathComponent(), withIntermediateDirectories: true)
        if (try? Data(contentsOf: command)) != script {
            try script.write(to: command, options: .atomic)
        }
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: command.path)

        let settings = account.configDir.appendingPathComponent("settings.json")
        let wanted: [String: Any] = ["type": "command", "command": self.command(for: account, home: home)]
        var object: [String: Any] = [:]
        if fileManager.fileExists(atPath: settings.path) {
            guard let data = try? Data(contentsOf: settings),
                  let parsed = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                return .unreadableSettings
            }
            object = parsed
            if let current = object["statusLine"] as? [String: Any] {
                if current["type"] as? String == "command",
                   current["command"] as? String == self.command(for: account, home: home) {
                    return .alreadySet
                }
                if current["command"] as? String == wrapperURL(for: account, home: home).path { return .wrapped }
                return .otherStatusLine(current["command"] as? String ?? "")
            }
            if object["statusLine"] != nil { return .otherStatusLine("") }
            let backup = account.configDir.appendingPathComponent("settings.json.tokenmeter.bak")
            try? fileManager.removeItem(at: backup)
            try fileManager.copyItem(at: settings, to: backup)
        }

        object["statusLine"] = wanted
        let output = try JSONSerialization.data(
            withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try (output + Data("\n".utf8)).write(to: settings, options: .atomic)
        return .set
    }

    public static func otherStatusLine(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> String? {
        otherStatusLine(account: .default(home: home), home: home)
    }

    /// The status line someone else set in the account's `settings.json`, read only; nil when there is none or it is
    /// tokenmeter's own or its wrapper. The command is empty when the status line is not a `command` one.
    public static func otherStatusLine(account: Account, home: URL = FileManager.default.homeDirectoryForCurrentUser) -> String? {
        let settings = account.configDir.appendingPathComponent("settings.json")
        guard let data = try? Data(contentsOf: settings),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let value = object["statusLine"] else { return nil }
        guard let current = value as? [String: Any], current["type"] as? String == "command",
              let command = current["command"] as? String else { return "" }
        return isOwn(command, account: account, home: home) ? nil : command
    }

    public enum WrapOutcome: Equatable, Sendable {
        case notInstalled
        /// The status line is wrapped now.
        case wrapped
        case alreadyWrapped
        /// Nothing to wrap: no status line, or tokenmeter's own.
        case nothingToWrap
        /// The status line is not a `command` one; it was left alone.
        case notWrappable
        case unreadableSettings
    }

    public enum RestoreOutcome: Equatable, Sendable {
        case restored
        /// `statusLine` is not the wrapper (never wrapped, or changed by hand); nothing was touched.
        case notWrapped
        case unreadableSettings
    }

    public static func wrap(script: Data, home: URL = FileManager.default.homeDirectoryForCurrentUser) throws -> WrapOutcome {
        try wrap(script: script, account: .default(home: home), home: home)
    }

    /// Wraps another status line (ADR 0004): `statusLine.command` becomes a script that gives the same
    /// input to tokenmeter's script and to the original command, and prints only the original's output.
    public static func wrap(script: Data, account: Account,
                            home: URL = FileManager.default.homeDirectoryForCurrentUser) throws -> WrapOutcome {
        let fileManager = FileManager.default
        let settings = account.configDir.appendingPathComponent("settings.json")
        guard fileManager.fileExists(atPath: settings.path) else {
            return fileManager.fileExists(atPath: account.configDir.path) ? .nothingToWrap : .notInstalled
        }
        guard let data = try? Data(contentsOf: settings),
              var object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return .unreadableSettings
        }
        guard let current = object["statusLine"] as? [String: Any] else {
            return object["statusLine"] == nil ? .nothingToWrap : .notWrappable
        }
        let tokenmeter = scriptURL(home: home)
        let wrapper = wrapperURL(for: account, home: home)
        guard current["type"] as? String == "command", let original = current["command"] as? String else {
            return .notWrappable
        }
        if original == wrapper.path { return .alreadyWrapped }
        if original == tokenmeter.path || original == command(for: account, home: home) { return .nothingToWrap }

        try fileManager.createDirectory(at: wrapper.deletingLastPathComponent(), withIntermediateDirectories: true)
        try script.write(to: tokenmeter, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tokenmeter.path)

        let saved = try JSONSerialization.data(
            withJSONObject: current, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try saved.write(to: originalURL(for: account, home: home), options: .atomic)
        let quoted = original.replacingOccurrences(of: "'", with: "'\\''")
        let body = """
        #!/bin/sh
        # Wraps the status line that was set before tokenmeter (ADR 0004). Restore it from tokenmeter's Settings.
        input=$(cat)
        printf '%s' "$input" | '\(tokenmeter.path)' \(account.id == AccountTool.claudeCode.seedID ? "" : "'\(account.id)' ")>/dev/null 2>&1
        printf '%s' "$input" | sh -c '\(quoted)'

        """
        try Data(body.utf8).write(to: wrapper, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: wrapper.path)

        let backup = account.configDir.appendingPathComponent("settings.json.tokenmeter.bak")
        try? fileManager.removeItem(at: backup)
        try fileManager.copyItem(at: settings, to: backup)
        var wrapped = current
        wrapped["command"] = wrapper.path
        object["statusLine"] = wrapped
        let output = try JSONSerialization.data(
            withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try (output + Data("\n".utf8)).write(to: settings, options: .atomic)
        return .wrapped
    }

    public static func restore(home: URL = FileManager.default.homeDirectoryForCurrentUser) throws -> RestoreOutcome {
        try restore(account: .default(home: home), home: home)
    }

    /// Puts the saved status line back and removes the wrapper. Never overwrites a `statusLine` that is not the wrapper.
    public static func restore(account: Account,
                               home: URL = FileManager.default.homeDirectoryForCurrentUser) throws -> RestoreOutcome {
        let fileManager = FileManager.default
        let settings = account.configDir.appendingPathComponent("settings.json")
        let wrapper = wrapperURL(for: account, home: home)
        guard let data = try? Data(contentsOf: settings),
              var object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return fileManager.fileExists(atPath: settings.path) ? .unreadableSettings : .notWrapped
        }
        guard let current = object["statusLine"] as? [String: Any], current["command"] as? String == wrapper.path,
              let saved = try? Data(contentsOf: originalURL(for: account, home: home)),
              let original = (try? JSONSerialization.jsonObject(with: saved)) as? [String: Any] else {
            return .notWrapped
        }
        object["statusLine"] = original
        let output = try JSONSerialization.data(
            withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try (output + Data("\n".utf8)).write(to: settings, options: .atomic)
        try? fileManager.removeItem(at: wrapper)
        try? fileManager.removeItem(at: originalURL(for: account, home: home))
        return .restored
    }
}
