import Foundation

/// Where a window stands against a steady use of its quota (ADR 0038, ADR 0039).
public struct Pace: Equatable, Sendable {
    /// The share of the window still ahead when the figure was observed: where the bar would end at a steady use. The quota
    /// runs out before the reset exactly when what is left is under this.
    public let aheadFraction: Double
    /// When the quota runs out at the pace it has had since the window began; nil when it lasts until the reset.
    public let runsOutAt: Date?

    public var runsOut: Bool { runsOutAt != nil }
}

extension WindowUsage {
    /// A reported figure older than this no longer counts as live (ADR 0008).
    public static let staleAfter: TimeInterval = 10 * 60

    /// Less of the window than this has gone: the pace says too little to be believed (ADR 0038).
    public static let minimumElapsed = 0.10

    /// The pace of the window. Nil when nothing can be estimated: not a fresh reported figure, no reset time, or too little of
    /// the window gone (ADR 0038). Where nothing was used it lasts, so it has a mark and no moment it runs out (ADR 0039).
    public func pace(at now: Date) -> Pace? {
        guard source == .reported, let remainingFraction, let resetsAt, let observedAt,
              resetsAt > now, now.timeIntervalSince(observedAt) <= Self.staleAfter, window.duration > 0 else { return nil }
        let used = 1 - remainingFraction
        let start = resetsAt.addingTimeInterval(-window.duration)
        let elapsed = observedAt.timeIntervalSince(start)
        guard elapsed >= window.duration * Self.minimumElapsed, elapsed < window.duration else { return nil }
        let ahead = resetsAt.timeIntervalSince(observedAt) / window.duration
        guard used > 0 else { return Pace(aheadFraction: ahead, runsOutAt: nil) }
        let runsOut = start.addingTimeInterval(elapsed / used)
        return Pace(aheadFraction: ahead, runsOutAt: runsOut < resetsAt ? runsOut : nil)
    }

    /// When the quota runs out at the pace it has had since the window began, if that is before the reset (ADR 0038).
    /// Nil when it lasts, and when nothing can be estimated.
    public func runsOut(at now: Date) -> Date? {
        pace(at: now)?.runsOutAt
    }

    /// The hover on the bar (ADR 0039): "At this pace you run out Thursday at 6 pm", or that it lasts until the reset.
    /// Nil when nothing can be estimated, and then the bar has no mark either.
    public func paceHoverText(at now: Date, calendar: Calendar = .current) -> String? {
        guard let pace = pace(at: now) else { return nil }
        guard let moment = pace.runsOutAt else { return "At this pace it lasts until the reset" }
        let when = Self.rounded(moment, from: now, calendar: calendar, weekday: "EEEE")
        return "At this pace you run out \(when.day) at \(when.clock)"
    }

    /// The same moment in short, for the widget's detail line (ADR 0039): "out Thu 6 pm". Nil when it lasts, and when
    /// nothing can be estimated.
    public func runsOutShortText(at now: Date, calendar: Calendar = .current) -> String? {
        guard let moment = runsOut(at: now) else { return nil }
        let when = Self.rounded(moment, from: now, calendar: calendar, weekday: "EEE")
        return "out \(when.day) \(when.clock)"
    }

    /// The moment rounded to the hour: "6 pm", and the day as today, tomorrow or the weekday in the given format.
    private static func rounded(_ moment: Date, from now: Date, calendar: Calendar, weekday: String) -> (day: String, clock: String) {
        let hour = calendar.dateInterval(of: .hour, for: moment.addingTimeInterval(30 * 60))?.start ?? moment
        let parts = calendar.dateComponents([.hour], from: hour)
        let clock = parts.hour.map { ($0 % 12 == 0 ? 12 : $0 % 12).description + ($0 < 12 ? " am" : " pm") } ?? ""
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: hour)).day ?? 0
        let day: String
        switch days {
        case ..<1: day = "today"
        case 1: day = "tomorrow"
        default:
            // The interface is in English, like "resets in 2h".
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.locale = Locale(identifier: "en_US")
            formatter.dateFormat = weekday
            day = formatter.string(from: hour)
        }
        return (day, clock)
    }
}
