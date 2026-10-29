import Foundation

/// Turns a raw plan identifier into a label when no rule names it (ADR 0012, 0017).
public enum PlanName {
    /// `team_plus` becomes `Team Plus`.
    public static func prettified(_ raw: String) -> String {
        raw.split(separator: "_").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }
}
