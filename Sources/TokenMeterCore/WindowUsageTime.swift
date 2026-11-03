import Foundation

/// What a window says about time, measured at the moment it is asked for and not at the one the code runs in. The panel passes
/// the current moment; the widget passes the date of the entry of its timeline, so an entry drawn ahead of time reads as it will
/// when it is shown (ADR 0002).
extension WindowUsage {
    /// A reported figure older than `staleAfter` at `now`: it can only have gone down since.
    public func isStale(at now: Date) -> Bool {
        guard source == .reported, let observedAt else { return false }
        return now.timeIntervalSince(observedAt) > Self.staleAfter
    }

    /// True when the figure is old or inferred rather than a fresh provider reading.
    public func isApproximate(at now: Date) -> Bool { isStale(at: now) || source == .reset }

    /// "3h ago" style; nil when the figure was never observed.
    public func observedAgoText(at now: Date) -> String? {
        guard let observedAt else { return nil }
        let minutes = Int(now.timeIntervalSince(observedAt) / 60)
        return minutes >= 1440 ? "\(minutes / 1440)d ago" : minutes >= 60 ? "\(minutes / 60)h ago" : "\(max(minutes, 1))m ago"
    }

    /// "in 2h 10m" style; nil when the provider gave no reset time or it has passed at `now`.
    public func resetText(at now: Date) -> String? {
        guard let resetsAt else { return nil }
        let minutes = Int(resetsAt.timeIntervalSince(now) / 60)
        guard minutes > 0 else { return nil }
        return minutes >= 60 * 24 ? "in \(minutes / 1440)d \(minutes % 1440 / 60)h"
            : minutes >= 60 ? "in \(minutes / 60)h \(minutes % 60)m" : "in \(minutes)m"
    }
}
