import Foundation

/// The checks of the app itself, topic `general` (ADR 0030). Each takes what it needs and does no I/O.
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

    /// Every kind of problem the app itself can report.
    public static let kinds = [noAppGroup, integrationNotFound]

    public static func check(hasAppGroup: Bool) -> [Problem] {
        guard !hasAppGroup else { return [] }
        return [noAppGroup.problem(detail: "No App Group: set DEVELOPMENT_TEAM in Local.xcconfig for the widget.")]
    }
}
