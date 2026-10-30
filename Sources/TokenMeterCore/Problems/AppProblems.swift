import Foundation

/// The checks of the app itself, topic `general` (ADR 0030). Each takes what it needs and does no I/O.
public enum AppProblems {
    public static func check(hasAppGroup: Bool) -> [Problem] {
        guard !hasAppGroup else { return [] }
        return [Problem(id: "general.appgroup", topic: Problem.general, message: "The widget cannot read the data",
                        detail: "No App Group: set DEVELOPMENT_TEAM in Local.xcconfig for the widget.",
                        guide: "use/troubleshooting")]
    }
}
