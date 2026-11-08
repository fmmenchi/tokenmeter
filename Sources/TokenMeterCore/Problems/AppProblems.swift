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

    public static let folderNotNamed = ProblemKind(
        id: "general.folder", topic: Problem.general, summary: "A folder of a tool is not in providers.json",
        explanation: "A folder at the top of your home holds what Claude Code or the Codex CLI leaves in one, with its own "
            + "login, and no entry of ~/.tokenmeter/providers.json names it as its home, so it has no card. Add it writes an "
            + "entry for it; Dismiss hides this until the folder changes; the guide says how to write the entry by hand.",
        guide: "use/accounts")

    /// Every kind of problem the app itself can report.
    public static let kinds = [noAppGroup, integrationNotFound, providersFileBroken, snapshotNotWritten, folderNotNamed]

    /// A folder of a tool that no entry names (ADR 0014): one problem per folder, named by the folder, with who is signed
    /// in there. The detector decides which folders those are; this only says it.
    public static func folderNotNamed(_ found: AccountFolders.Found, userHome: URL) -> Problem {
        let path = found.folder.standardizedFileURL.path
        let home = userHome.standardizedFileURL.path
        let shown = path.hasPrefix(home + "/") ? "~" + path.dropFirst(home.count) : path
        let login = found.email.map { "is signed in as \($0)" } ?? "has no login yet"
        return folderNotNamed.problem(
            message: "A \(found.tool.name) folder is not in providers.json",
            detail: "\(shown) \(login), and no entry names it. Add it writes an entry, and the card appears.",
            detailID: String(found.folder.lastPathComponent.drop(while: { $0 == "." })))
    }

    /// What the app found about itself. The errors are the last outcomes the app saw; nil is good or not asked yet.
    public static func check(hasAppGroup: Bool, providersFileError: String? = nil,
                             snapshotWriteError: String? = nil) -> [Problem] {
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
        return found
    }
}
