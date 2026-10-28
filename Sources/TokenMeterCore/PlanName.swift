import Foundation

/// Turns the raw plan identifiers the CLIs record into a label (ADR 0012).
public enum PlanName {
    public static func claude(organizationType: String?, rateLimitTier: String?) -> String? {
        let tier = rateLimitTier?.lowercased() ?? ""
        if tier.contains("max_20x") { return "Max 20x" }
        if tier.contains("max_5x") { return "Max 5x" }
        switch organizationType?.lowercased() {
        case "claude_max": return "Max"
        case "claude_pro": return "Pro"
        case "claude_team": return "Team"
        case "claude_enterprise": return "Enterprise"
        case let other?: return prettify(other.replacingOccurrences(of: "claude_", with: ""))
        case nil: return nil
        }
    }

    public static func chatgpt(planType: String?) -> String? {
        planType.map { prettify($0) }
    }

    private static func prettify(_ raw: String) -> String {
        raw.split(separator: "_").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }
}
