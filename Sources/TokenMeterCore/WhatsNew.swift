import Foundation

/// A new feature, as the panel's card and the "What's new" window say it (feature "what's new"). Fixes have no entry: they stay in
/// the changelog.
public struct WhatsNewEntry: Equatable, Sendable {
    public let version: String
    public let title: String
    public let detail: String
}

/// The features that are new since the version a person last saw. The entries are written here, one per feature, when a version that
/// has features is released.
public enum WhatsNew {
    public static let entries: [WhatsNewEntry] = [
        WhatsNewEntry(version: "0.17.0", title: "The quota in the menu bar",
                      detail: "Beside the gauge, a figure for each card, in the panel's order: the window with the least left. Settings › General turns it off."),
        WhatsNewEntry(version: "0.16.0", title: "A command for Terminal",
                      detail: "tokenmeter prints the quota and the stats in Terminal, as text or JSON. Settings › General copies the line that installs it."),
        WhatsNewEntry(version: "0.15.0", title: "The cost in dollars",
                      detail: "The stats show what your tokens would cost at the providers' API list prices, by model and for the range. An estimate, not what a plan costs."),
        WhatsNewEntry(version: "0.15.0", title: "A week ending mostly unused is said",
                      detail: "In the last 2 days of a week with half its quota left, the Weekly bar says so, and a new notice can tell it once."),
        WhatsNewEntry(version: "0.14.0", title: "Empty cards instead of a spinner",
                      detail: "While the data arrives, the panel and the stats draw their cards empty, in the grey of the skin."),
    ]

    /// `0.9.2` before `0.10.0`: compared by number, part by part.
    public static func isBefore(_ a: String, _ b: String) -> Bool {
        let left = a.split(separator: ".").map { Int($0) ?? 0 }
        let right = b.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(left.count, right.count) {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l != r { return l < r }
        }
        return false
    }

    /// What is new, newest first. On a first launch nothing (the welcome is for that); with no version seen before, the installed
    /// version's own features, since the one the person came from is not known; otherwise those after it, up to the installed one.
    public static func new(since lastSeen: String?, installed: String, firstLaunch: Bool,
                           entries: [WhatsNewEntry] = entries) -> [WhatsNewEntry] {
        guard !firstLaunch else { return [] }
        return entries.filter { entry in
            guard !isBefore(installed, entry.version) else { return false }
            guard let lastSeen else { return entry.version == installed }
            return isBefore(lastSeen, entry.version)
        }
        .sorted { isBefore($1.version, $0.version) }
    }
}
