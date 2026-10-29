import Foundation

/// Sets up the Claude Code status line that leaves the quota on disk (ADR 0005, 0024).
/// It never replaces a status line someone else set, and never touches a settings file it cannot read.
public enum ClaudeStatusLine {
    public enum Outcome: Equatable, Sendable {
        /// No `~/.claude`: nothing was created.
        case notInstalled
        case set
        case alreadySet
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
}
