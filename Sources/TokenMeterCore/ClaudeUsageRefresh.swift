import Foundation

/// Asks Claude Code to refresh the usage copy it keeps in `~/.claude.json`, by running its own `/usage` (ADR 0002).
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

    /// Resumes a continuation once, whichever of the exit and the timeout comes first.
    private final class Once: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<Outcome, Never>?

        init(_ continuation: CheckedContinuation<Outcome, Never>) { self.continuation = continuation }

        func finish(_ outcome: Outcome) {
            lock.lock()
            let pending = continuation
            continuation = nil
            lock.unlock()
            pending?.resume(returning: outcome)
        }
    }

    /// Runs `executable` in `folder` (made if missing) and waits at most `timeout` seconds. The wait holds no thread: the caller
    /// is suspended until the process ends or the time is up, so a CLI that hangs costs nothing but the process itself.
    public static func run(executable: URL, in folder: URL, timeout: TimeInterval = 45) async -> Outcome {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = folder
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        return await withCheckedContinuation { (continuation: CheckedContinuation<Outcome, Never>) in
            let once = Once(continuation)
            process.terminationHandler = { finished in
                once.finish(finished.terminationStatus == 0 ? .refreshed : .failed("exit \(finished.terminationStatus)"))
            }
            do { try process.run() } catch {
                once.finish(.failed(error.localizedDescription))
                return
            }
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
                guard process.isRunning else { return }
                // The outcome first: ending the process makes the termination handler answer too, and the first answer counts.
                once.finish(.timedOut)
                process.terminate()
            }
        }
    }

    /// Finds the CLI and runs it in `~/.tokenmeter/claude/`, away from every project.
    public static func refresh(home: URL = FileManager.default.homeDirectoryForCurrentUser,
                               path: String = ProcessInfo.processInfo.environment["PATH"] ?? "",
                               system: [String] = ["/opt/homebrew/bin", "/usr/local/bin"],
                               timeout: TimeInterval = 45) async -> Outcome {
        guard let executable = locate(home: home, path: path, system: system) else { return .notFound }
        return await run(executable: executable, in: home.appendingPathComponent(".tokenmeter/claude"), timeout: timeout)
    }
}
