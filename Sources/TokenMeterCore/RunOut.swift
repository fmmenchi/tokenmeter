import Foundation

extension WindowUsage {
    /// A reported figure older than this no longer counts as live (ADR 0008).
    public static let staleAfter: TimeInterval = 10 * 60

    /// Less of the window than this has gone: the pace says too little to be believed (ADR 0038).
    public static let minimumElapsed = 0.10

    /// When the quota runs out at the pace it has had since the window began, if that is before the reset (ADR 0038).
    /// Nil when it lasts, and when nothing can be estimated: not a fresh reported figure, no reset time, nothing used, or
    /// too little of the window gone.
    public func runsOut(at now: Date) -> Date? {
        guard source == .reported, let remainingFraction, let resetsAt, let observedAt,
              resetsAt > now, now.timeIntervalSince(observedAt) <= Self.staleAfter, window.duration > 0 else { return nil }
        let used = 1 - remainingFraction
        let start = resetsAt.addingTimeInterval(-window.duration)
        let elapsed = observedAt.timeIntervalSince(start)
        guard used > 0, elapsed >= window.duration * Self.minimumElapsed, elapsed < window.duration else { return nil }
        let runsOut = start.addingTimeInterval(elapsed / used)
        return runsOut < resetsAt ? runsOut : nil
    }

    /// "at this pace you run out Thursday at 6 pm": the moment rounded to the hour, as today, tomorrow or the weekday.
    public func runsOutText(at now: Date, calendar: Calendar = .current) -> String? {
        guard let moment = runsOut(at: now) else { return nil }
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
            formatter.dateFormat = "EEEE"
            day = formatter.string(from: hour)
        }
        return "at this pace you run out \(day) at \(clock)"
    }
}
