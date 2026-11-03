import Foundation

/// The checks of the app itself, topic `general` (ADR 0005). Each takes what it needs and does no I/O.
public enum AppProblems {
    public static let noAppGroup = ProblemKind(
        id: "general.appgroup", topic: Problem.general, summary: "The widget cannot read the data",
        explanation: "The widget runs in its own process and reads the data through the App Group of your signing team. "
            + "This build has none, so the widget shows nothing. Set DEVELOPMENT_TEAM in Local.xcconfig, run xcodegen "
            + "generate and build again.",
        guide: "use/troubleshooting")

    public static let integrationNotFound = ProblemKind(
        id: "general.integration", topic: Problem.general, summary: "A provider asks for an integration this version does not have",
        explanation: "The integration field of a provider in ~/.tokenmeter/providers.json names something this version of "
            + "tokenmeter does not know, so that provider's problems cannot be reported. Check the spelling, or remove the "
            + "field. Reading its quota is not affected.",
        guide: "use/troubleshooting")

    public static let providersFileBroken = ProblemKind(
        id: "general.providersfile", topic: Problem.general, summary: "providers.json cannot be used",
        explanation: "~/.tokenmeter/providers.json exists but this version cannot read it, so tokenmeter runs on its built-in list "
            + "of Claude and ChatGPT. The file was not changed: fix what the detail says, or move the file aside and start the app "
            + "to get a fresh one.",
        guide: "use/configure-providers")

    public static let snapshotNotWritten = ProblemKind(
        id: "general.snapshotwrite", topic: Problem.general, summary: "The widget's data could not be written",
        explanation: "The app could not write the snapshot the widget reads, so the widget keeps showing what it had. The detail "
            + "says why: usually a full disk or a folder that is not writable. The panel is not affected.",
        guide: "use/troubleshooting")

    public static let usageRefreshFailed = ProblemKind(
        id: "general.usagerefresh", topic: Problem.general, summary: "Claude's model limits are not refreshing",
        explanation: "tokenmeter asks Claude Code to run its own /usage every 15 minutes, and it did not answer in time or failed, "
            + "so the limits of each model stop moving. The 5-hour and weekly bars come from the status line and are not affected. "
            + "Run claude once in a terminal to see whether it is signed in.",
        guide: "use/enable-claude-quota")

    /// Every kind of problem the app itself can report.
    public static let kinds = [noAppGroup, integrationNotFound, providersFileBroken, snapshotNotWritten, usageRefreshFailed]

    /// What the app found about itself. `providersFileError`, `snapshotWriteError` and `usageRefresh` are the last outcomes the
    /// app saw; nil is good or not asked yet. Claude Code not being installed (`.notFound`) is not a problem.
    public static func check(hasAppGroup: Bool, providersFileError: String? = nil, snapshotWriteError: String? = nil,
                             usageRefresh: ClaudeUsageRefresh.Outcome? = nil) -> [Problem] {
        var found: [Problem] = []
        if !hasAppGroup {
            found.append(noAppGroup.problem(detail: "No App Group: set DEVELOPMENT_TEAM in Local.xcconfig for the widget."))
        }
        if let providersFileError {
            found.append(providersFileBroken.problem(detail: providersFileError))
        }
        if let snapshotWriteError {
            found.append(snapshotNotWritten.problem(detail: snapshotWriteError))
        }
        switch usageRefresh {
        case .timedOut:
            found.append(usageRefreshFailed.problem(detail: "Claude Code did not answer /usage in time."))
        case .failed(let reason):
            found.append(usageRefreshFailed.problem(detail: "Claude Code failed: \(reason)."))
        case .refreshed, .notFound, nil:
            break
        }
        return found
    }
}
