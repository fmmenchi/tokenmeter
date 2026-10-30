import Foundation

/// What Claude needs beyond its logs: a status line that leaves the quota on disk (ADR 0005, 0025, 0026).
/// The first integration; it wraps `ClaudeStatusLine` and `ProjectStatusLines`.
public struct ClaudeIntegration: ProviderIntegration {
    public static let wrapStatusLine = "wrapStatusLine"

    public let id = "claude-status-line"
    /// The script tokenmeter's status line runs, from the app bundle; nil where there is none (a fix then fails).
    private let script: Data?

    /// False while the person has turned the status line setup off: they chose not to have it, so it is not a problem.
    private let enabled: Bool

    public init(script: Data?, enabled: Bool = true) {
        self.script = script
        self.enabled = enabled
    }

    public var fixes: [FixDescriptor] {
        [FixDescriptor(
            id: Self.wrapStatusLine, label: "Wrap it", runningLabel: "Wrapping…",
            explanation: """
            Wrap it changes statusLine in ~/.claude/settings.json to a small script in ~/.tokenmeter/claude/. \
            The script gives Claude's data to tokenmeter and still prints your own status line, unchanged. \
            Your setting is saved first, and settings.json.tokenmeter.bak keeps a copy. \
            Restore original in Settings puts it back.
            """)]
    }

    public func problems(in context: ProblemContext) -> [Problem] {
        guard enabled else { return [] }
        var found: [Problem] = []
        if let command = ClaudeStatusLine.otherStatusLine(home: context.home) {
            found.append(Problem(
                id: "claude.statusline.other", topic: "claude", message: "Another status line is in use",
                detail: "It was left alone, so the Claude bars do not update.",
                fix: command.isEmpty ? nil : Self.wrapStatusLine, guide: "use/enable-claude-quota"))
        }
        let overrides = ProjectStatusLines.overrides(home: context.home, now: context.now)
        if !overrides.isEmpty {
            let names = overrides.prefix(3).map(\.project.lastPathComponent).joined(separator: ", ")
            let more = overrides.count > 3 ? " +\(overrides.count - 3)" : ""
            let count = overrides.count
            found.append(Problem(
                id: "claude.statusline.projects",
                topic: "claude",
                message: count == 1 ? "1 project sets its own status line" : "\(count) projects set their own status line",
                detail: "Claude bars freeze there: \(names)\(more).", guide: "use/enable-claude-quota"))
        }
        return found
    }

    public func run(fix: String, in context: ProblemContext) -> FixResult {
        guard fix == Self.wrapStatusLine else { return .failed("Unknown fix \(fix).") }
        guard let script else { return .failed("The status line script is missing from the app. Nothing was changed.") }
        do {
            switch try ClaudeStatusLine.wrap(script: script, home: context.home) {
            case .wrapped, .alreadyWrapped: return .done
            case .notInstalled: return .failed("Claude Code is not installed. Nothing was changed.")
            case .nothingToWrap: return .failed("There is no other status line to wrap. Nothing was changed.")
            case .notWrappable: return .failed("That status line is not a command, so it cannot be wrapped. Nothing was changed.")
            case .unreadableSettings: return .failed("settings.json could not be read as JSON. Nothing was changed.")
            }
        } catch {
            return .failed("settings.json could not be written. Nothing was changed.")
        }
    }
}
