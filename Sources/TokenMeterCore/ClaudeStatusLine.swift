import Foundation

/// Sets up the Claude Code status line that leaves the quota on disk (ADR 0005, 0024).
/// It never replaces a status line someone else set, and never touches a settings file it cannot read.
public enum ClaudeStatusLine {
    public enum Outcome: Equatable, Sendable {
        /// No `~/.claude`: nothing was created.
        case notInstalled
        case set
        case alreadySet
        /// Another status line was wrapped, so both it and tokenmeter's script get the input (ADR 0025).
        case wrapped
        /// Another status line is in use; it was left alone. Carries its command.
        case otherStatusLine(String)
        /// `settings.json` could not be read as a JSON object; it was left alone.
        case unreadableSettings
    }

    public static func setUp(script: Data, home: URL = FileManager.default.homeDirectoryForCurrentUser) throws -> Outcome {
        let fileManager = FileManager.default
        let claude = home.appendingPathComponent(".claude")
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: claude.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return .notInstalled
        }

        let folder = home.appendingPathComponent(".tokenmeter")
        let command = folder.appendingPathComponent("claude-statusline.sh")
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        if (try? Data(contentsOf: command)) != script {
            try script.write(to: command, options: .atomic)
        }
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: command.path)

        let settings = claude.appendingPathComponent("settings.json")
        let wanted: [String: Any] = ["type": "command", "command": command.path]
        var object: [String: Any] = [:]
        if fileManager.fileExists(atPath: settings.path) {
            guard let data = try? Data(contentsOf: settings),
                  let parsed = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                return .unreadableSettings
            }
            object = parsed
            if let current = object["statusLine"] as? [String: Any] {
                if current["type"] as? String == "command", current["command"] as? String == command.path {
                    return .alreadySet
                }
                if current["command"] as? String == wrapperURL(home: home).path { return .wrapped }
                return .otherStatusLine(current["command"] as? String ?? "")
            }
            if object["statusLine"] != nil { return .otherStatusLine("") }
            let backup = claude.appendingPathComponent("settings.json.tokenmeter.bak")
            try? fileManager.removeItem(at: backup)
            try fileManager.copyItem(at: settings, to: backup)
        }

        object["statusLine"] = wanted
        let output = try JSONSerialization.data(
            withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try (output + Data("\n".utf8)).write(to: settings, options: .atomic)
        return .set
    }

    /// The status line someone else set in `~/.claude/settings.json`, read only; nil when there is none or it is
    /// tokenmeter's own or its wrapper. The command is empty when the status line is not a `command` one.
    public static func otherStatusLine(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> String? {
        let settings = home.appendingPathComponent(".claude/settings.json")
        guard let data = try? Data(contentsOf: settings),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let value = object["statusLine"] else { return nil }
        guard let current = value as? [String: Any], current["type"] as? String == "command",
              let command = current["command"] as? String else { return "" }
        let own = [home.appendingPathComponent(".tokenmeter/claude-statusline.sh").path, wrapperURL(home: home).path]
        return own.contains(command) ? nil : command
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

    static func wrapperURL(home: URL) -> URL {
        home.appendingPathComponent(".tokenmeter/claude/statusline-wrapper.sh")
    }

    private static func originalURL(home: URL) -> URL {
        home.appendingPathComponent(".tokenmeter/claude/original-statusline.json")
    }

    /// Wraps another status line (ADR 0025): `statusLine.command` becomes a script that gives the same
    /// input to tokenmeter's script and to the original command, and prints only the original's output.
    public static func wrap(script: Data, home: URL = FileManager.default.homeDirectoryForCurrentUser) throws -> WrapOutcome {
        let fileManager = FileManager.default
        let claude = home.appendingPathComponent(".claude")
        let settings = claude.appendingPathComponent("settings.json")
        guard fileManager.fileExists(atPath: settings.path) else {
            return fileManager.fileExists(atPath: claude.path) ? .nothingToWrap : .notInstalled
        }
        guard let data = try? Data(contentsOf: settings),
              var object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return .unreadableSettings
        }
        guard let current = object["statusLine"] as? [String: Any] else {
            return object["statusLine"] == nil ? .nothingToWrap : .notWrappable
        }
        let tokenmeter = home.appendingPathComponent(".tokenmeter/claude-statusline.sh")
        let wrapper = wrapperURL(home: home)
        guard current["type"] as? String == "command", let original = current["command"] as? String else {
            return .notWrappable
        }
        if original == wrapper.path { return .alreadyWrapped }
        if original == tokenmeter.path { return .nothingToWrap }

        let folder = wrapper.deletingLastPathComponent()
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        try script.write(to: tokenmeter, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tokenmeter.path)

        let saved = try JSONSerialization.data(
            withJSONObject: current, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try saved.write(to: originalURL(home: home), options: .atomic)
        let quoted = original.replacingOccurrences(of: "'", with: "'\\''")
        let body = """
        #!/bin/sh
        # Wraps the status line that was set before tokenmeter (ADR 0025). Restore it from tokenmeter's Settings.
        input=$(cat)
        printf '%s' "$input" | '\(tokenmeter.path)' >/dev/null 2>&1
        printf '%s' "$input" | sh -c '\(quoted)'

        """
        try Data(body.utf8).write(to: wrapper, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: wrapper.path)

        let backup = claude.appendingPathComponent("settings.json.tokenmeter.bak")
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

    /// Puts the saved status line back and removes the wrapper. Never overwrites a `statusLine` that is not the wrapper.
    public static func restore(home: URL = FileManager.default.homeDirectoryForCurrentUser) throws -> RestoreOutcome {
        let fileManager = FileManager.default
        let settings = home.appendingPathComponent(".claude/settings.json")
        let wrapper = wrapperURL(home: home)
        guard let data = try? Data(contentsOf: settings),
              var object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return fileManager.fileExists(atPath: settings.path) ? .unreadableSettings : .notWrapped
        }
        guard let current = object["statusLine"] as? [String: Any], current["command"] as? String == wrapper.path,
              let saved = try? Data(contentsOf: originalURL(home: home)),
              let original = (try? JSONSerialization.jsonObject(with: saved)) as? [String: Any] else {
            return .notWrapped
        }
        object["statusLine"] = original
        let output = try JSONSerialization.data(
            withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try (output + Data("\n".utf8)).write(to: settings, options: .atomic)
        try? fileManager.removeItem(at: wrapper)
        try? fileManager.removeItem(at: originalURL(home: home))
        return .restored
    }
}
