import Foundation

/// Where a window stands against a steady use of its quota (ADR 0038, ADR 0039).
public struct Pace: Equatable, Sendable {
    /// The share of the window still ahead: where the bar would end at a steady use. For a fresh figure it is the share when the
    /// figure was observed, and the quota runs out before the reset exactly when what is left is under it. For a figure that is
    /// out of date it is the share now.
    public let aheadFraction: Double
    /// When the quota runs out at the pace it has had since the window began; nil when it lasts until the reset, and for a
    /// figure that is out of date, which gives no moment.
    public let runsOutAt: Date?
    /// The figure is older than `WindowUsage.staleAfter`: it can only have gone down since (ADR 0008).
    public let isStale: Bool
    /// The quota runs out before the reset. For a figure that is out of date this is only said when the reading itself is
    /// already under `aheadFraction`: then it runs out even if nothing was used since.
    public let runsOut: Bool
}

extension WindowUsage {
    /// A reported figure older than this no longer counts as live (ADR 0008).
    public static let staleAfter: TimeInterval = 10 * 60

    /// Less of the window than this has gone: the pace says too little to be believed (ADR 0038).
    public static let minimumElapsed = 0.10

    /// The pace of the window. Nil when nothing can be estimated: not a reported figure, no reset time, or too little of the
    /// window gone (ADR 0038). Where nothing was used it lasts, so it has a mark and no moment it runs out (ADR 0039). A
    /// figure that is out of date has a mark too, measured now, and no moment (ADR 0039).
    public func pace(at now: Date) -> Pace? {
        guard source == .reported, let remainingFraction, let resetsAt, let observedAt,
              resetsAt > now, window.duration > 0 else { return nil }
        let start = resetsAt.addingTimeInterval(-window.duration)
        if now.timeIntervalSince(observedAt) > Self.staleAfter {
            let elapsedNow = now.timeIntervalSince(start)
            guard elapsedNow >= window.duration * Self.minimumElapsed, elapsedNow < window.duration else { return nil }
            let ahead = resetsAt.timeIntervalSince(now) / window.duration
            return Pace(aheadFraction: ahead, runsOutAt: nil, isStale: true, runsOut: remainingFraction < ahead)
        }
        let used = 1 - remainingFraction
        let elapsed = observedAt.timeIntervalSince(start)
        guard elapsed >= window.duration * Self.minimumElapsed, elapsed < window.duration else { return nil }
        let ahead = resetsAt.timeIntervalSince(observedAt) / window.duration
        guard used > 0 else { return Pace(aheadFraction: ahead, runsOutAt: nil, isStale: false, runsOut: false) }
        let runsOut = start.addingTimeInterval(elapsed / used)
        let moment = runsOut < resetsAt ? runsOut : nil
        return Pace(aheadFraction: ahead, runsOutAt: moment, isStale: false, runsOut: moment != nil)
    }

    /// When the quota runs out at the pace it has had since the window began, if that is before the reset (ADR 0038).
    /// Nil when it lasts, and when nothing can be estimated.
    public func runsOut(at now: Date) -> Date? {
        pace(at: now)?.runsOutAt
    }

    /// What the figure on the bar's label line says while the pointer is on the bar (ADR 0039): "out Thu 6 pm" where the quota
    /// runs out, "lasts" where it lasts. For a figure that is out of date, how old it is ("22 min ago"), or "runs out" when
    /// the reading is already under the mark. Short, because it takes the place of "20% left". Nil when nothing can be
    /// estimated, and then the bar has no mark either.
    public func paceFigureText(at now: Date, calendar: Calendar = .current) -> String? {
        guard let pace = pace(at: now) else { return nil }
        if pace.isStale {
            return pace.runsOut ? "runs out" : "\(observedAt.map { Self.age(now.timeIntervalSince($0)) } ?? "a while") ago"
        }
        guard let moment = pace.runsOutAt else { return "lasts" }
        // Tomorrow is the weekday here, which is shorter: a window is never as long as a week, so the name is not ambiguous.
        let when = Self.rounded(moment, from: now, calendar: calendar, weekday: "EEE", namesTomorrow: true)
        return "out \(when.day) \(when.clock)"
    }

    /// "20 min", "3 h" or "5 d": how old a reading is.
    private static func age(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        return minutes >= 1440 ? "\(minutes / 1440) d" : minutes >= 60 ? "\(minutes / 60) h" : "\(max(minutes, 1)) min"
    }

    /// The same moment in short, for the widget's detail line (ADR 0039): "out Thu 6 pm". Nil when it lasts, and when
    /// nothing can be estimated.
    public func runsOutShortText(at now: Date, calendar: Calendar = .current) -> String? {
        guard let moment = runsOut(at: now) else { return nil }
        let when = Self.rounded(moment, from: now, calendar: calendar, weekday: "EEE")
        return "out \(when.day) \(when.clock)"
    }

    /// The moment rounded to the hour: "6 pm", and the day as today, tomorrow or the weekday in the given format.
    private static func rounded(_ moment: Date, from now: Date, calendar: Calendar, weekday: String,
                                namesTomorrow: Bool = false) -> (day: String, clock: String) {
        let hour = calendar.dateInterval(of: .hour, for: moment.addingTimeInterval(30 * 60))?.start ?? moment
        let parts = calendar.dateComponents([.hour], from: hour)
        let clock = parts.hour.map { ($0 % 12 == 0 ? 12 : $0 % 12).description + ($0 < 12 ? " am" : " pm") } ?? ""
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: hour)).day ?? 0
        let day: String
        switch days {
        case ..<1: day = "today"
        case 1 where !namesTomorrow: day = "tomorrow"
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
