import Foundation

/// Prepares a Terminal command that opens Claude Code's interactive Usage screen (ADR 0015).
/// Claude Code reads its own credentials and writes its usage cache; tokenmeter does neither.
public enum ClaudeUsageCommand {
    public enum Failure: LocalizedError {
        case notFound

        public var errorDescription: String? {
            switch self {
            case .notFound: "Claude Code was not found. Install it or add it to your PATH."
            }
        }
    }

    /// Where the CLI usually is. An app started from the Finder has a short `PATH`, so the places are listed.
    public static func locate(home: URL = FileManager.default.homeDirectoryForCurrentUser,
                              path: String = ProcessInfo.processInfo.environment["PATH"] ?? "",
                              system: [String] = ["/opt/homebrew/bin", "/usr/local/bin"]) -> URL? {
        let fixed = [".local/bin", ".claude/local", ".npm-global/bin", ".bun/bin"].map { home.appendingPathComponent($0) }
            + system.map { URL(fileURLWithPath: $0) }
        let onPath = path.split(separator: ":").map { URL(fileURLWithPath: String($0)) }
        return (fixed + onPath).map { $0.appendingPathComponent("claude") }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    /// A `.command` file opens in Terminal. The account folder may still ask for trust in Claude Code.
    @discardableResult
    public static func write(for account: ClaudeStatusLine.Account,
                             home: URL = FileManager.default.homeDirectoryForCurrentUser,
                             executable: URL? = nil, path: String = ProcessInfo.processInfo.environment["PATH"] ?? "",
                             system: [String] = ["/opt/homebrew/bin", "/usr/local/bin"]) throws -> URL {
        guard let executable = executable ?? locate(home: home, path: path, system: system) else { throw Failure.notFound }
        let folder = home.appendingPathComponent(".tokenmeter/\(account.id)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("open-usage.command")
        // The default folder is Claude Code's own default: the variable is cleared, never set to it (`environmentConfigDir`).
        let configDir = account.environmentConfigDir(home: home).map { "export CLAUDE_CONFIG_DIR=\(quoted($0.path))" }
            ?? "unset CLAUDE_CONFIG_DIR"
        let contents = """
        #!/bin/sh
        cd \(quoted(folder.path)) || exit 1
        \(configDir)
        export CLAUDE_CODE_SKIP_PROMPT_HISTORY=1
        exec \(quoted(executable.path)) /usage --no-chrome
        """ + "\n"
        try Data(contents.utf8).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        return url
    }

    private static func quoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
