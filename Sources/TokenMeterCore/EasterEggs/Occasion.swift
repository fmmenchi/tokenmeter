import Foundation

/// The events that have a week of small details in the panel (feature "seasonal easter eggs").
///
/// An event is on for the seven days up to and including the day it falls on. The days are in the person's own calendar and time
/// zone. Easter is worked out for each year; the other two are fixed.
public enum Occasion: String, CaseIterable, Sendable {
    case halloween
    case christmas
    case easter

    /// How many days an event is on, the day itself included.
    public static let weekLength = 7

    /// The event whose week it is on `date`, or nil. The weeks never overlap.
    public static func active(on date: Date, calendar: Calendar = .current) -> Occasion? {
        let today = calendar.startOfDay(for: date)
        let year = calendar.component(.year, from: today)
        return allCases.first { occasion in
            guard let day = occasion.day(inYear: year, calendar: calendar),
                  let first = calendar.date(byAdding: .day, value: -(weekLength - 1), to: day) else { return false }
            return today >= first && today <= day
        }
    }

    /// The day the event falls on in `year`, at the start of that day.
    public func day(inYear year: Int, calendar: Calendar = .current) -> Date? {
        let parts: (month: Int, day: Int)
        switch self {
        case .halloween: parts = (10, 31)
        case .christmas: parts = (12, 25)
        case .easter: parts = Self.easterSunday(year: year)
        }
        return calendar.date(from: DateComponents(year: year, month: parts.month, day: parts.day))
    }

    /// Easter Sunday of the Gregorian calendar (the Western Church), by the Meeus/Jones/Butcher method.
    public static func easterSunday(year: Int) -> (month: Int, day: Int) {
        let a = year % 19
        let b = year / 100, c = year % 100
        let d = b / 4, e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4, k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = (h + l - 7 * m + 114) % 31 + 1
        return (month, day)
    }
}
