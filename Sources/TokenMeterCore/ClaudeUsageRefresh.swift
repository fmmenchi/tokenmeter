import Foundation

/// Asks Claude Code to refresh the usage copy it keeps in `~/.claude.json`, by running its own `/usage` (ADR 0034).
/// Claude Code reads its own credentials; tokenmeter handles none and calls no API.
public enum ClaudeUsageRefresh {
    public enum Outcome: Equatable, Sendable {
        case refreshed
        /// No `claude` could be found where the app looks.
        case notFound
        case timedOut
        case failed(String)
    }

    /// No session file and no browser integration: the run is cheap and leaves nothing in `~/.claude/projects`.
    static let arguments = ["-p", "/usage", "--no-session-persistence", "--no-chrome"]

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

    /// Runs `executable` in `folder` (made if missing) and waits at most `timeout` seconds.
    public static func run(executable: URL, in folder: URL, timeout: TimeInterval = 45) -> Outcome {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = folder
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        do { try process.run() } catch { return .failed(error.localizedDescription) }
        if finished.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            return .timedOut
        }
        return process.terminationStatus == 0 ? .refreshed : .failed("exit \(process.terminationStatus)")
    }

    /// Finds the CLI and runs it in `~/.tokenmeter/claude/`, away from every project.
    public static func refresh(home: URL = FileManager.default.homeDirectoryForCurrentUser,
                               path: String = ProcessInfo.processInfo.environment["PATH"] ?? "",
                               system: [String] = ["/opt/homebrew/bin", "/usr/local/bin"],
                               timeout: TimeInterval = 45) -> Outcome {
        guard let executable = locate(home: home, path: path, system: system) else { return .notFound }
        return run(executable: executable, in: home.appendingPathComponent(".tokenmeter/claude"), timeout: timeout)
    }
}
