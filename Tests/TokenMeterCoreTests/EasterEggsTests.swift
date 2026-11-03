import XCTest
@testable import TokenMeterCore

/// Feature "seasonal easter eggs": which event is on, and what the panel carries.
final class EasterEggsTests: XCTestCase {
    private func calendar(_ zone: String = "UTC") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12, in zone: String = "UTC") -> Date {
        calendar(zone).date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    // MARK: Easter

    func testEasterSundayForKnownYears() {
        let known: [(Int, Int, Int)] = [(2024, 3, 31), (2025, 4, 20), (2026, 4, 5), (2027, 3, 28), (2028, 4, 16), (2029, 4, 1), (2030, 4, 21),
                                        (2038, 4, 25), (2011, 4, 24)]
        for (year, month, day) in known {
            let easter = Occasion.easterSunday(year: year)
            XCTAssertEqual(easter.month, month, "month of \(year)")
            XCTAssertEqual(easter.day, day, "day of \(year)")
        }
    }

    // MARK: The weeks

    func testHalloweenIsOnFromThe25thTo31stOctober() {
        XCTAssertNil(Occasion.active(on: date(2026, 10, 24), calendar: calendar()))
        for day in 25 ... 31 { XCTAssertEqual(Occasion.active(on: date(2026, 10, day), calendar: calendar()), .halloween, "\(day) October") }
        XCTAssertNil(Occasion.active(on: date(2026, 11, 1), calendar: calendar()))
    }

    func testChristmasIsOnFromThe19thTo25thDecember() {
        XCTAssertNil(Occasion.active(on: date(2026, 12, 18), calendar: calendar()))
        for day in 19 ... 25 { XCTAssertEqual(Occasion.active(on: date(2026, 12, day), calendar: calendar()), .christmas, "\(day) December") }
        XCTAssertNil(Occasion.active(on: date(2026, 12, 26), calendar: calendar()))
    }

    func testEasterIsTheSevenDaysUpToEasterSunday() {
        // 2026: Easter Sunday is the 5th of April, so the week begins on Monday the 30th of March.
        XCTAssertNil(Occasion.active(on: date(2026, 3, 29), calendar: calendar()))
        XCTAssertEqual(Occasion.active(on: date(2026, 3, 30), calendar: calendar()), .easter)
        XCTAssertEqual(Occasion.active(on: date(2026, 4, 5), calendar: calendar()), .easter)
        XCTAssertNil(Occasion.active(on: date(2026, 4, 6), calendar: calendar()))
        // 2027: Sunday the 28th of March, a week that begins on the 22nd.
        XCTAssertNil(Occasion.active(on: date(2027, 3, 21), calendar: calendar()))
        XCTAssertEqual(Occasion.active(on: date(2027, 3, 22), calendar: calendar()), .easter)
        XCTAssertEqual(Occasion.active(on: date(2027, 3, 28), calendar: calendar()), .easter)
    }

    func testAnOrdinaryDayHasNoEvent() {
        XCTAssertNil(Occasion.active(on: date(2026, 7, 14), calendar: calendar()))
        XCTAssertNil(Occasion.active(on: date(2026, 1, 1), calendar: calendar()))
    }

    func testTheWeeksNeverOverlapInAnyYear() {
        let utc = calendar()
        for year in 2000 ... 2100 {
            var onDays = 0
            var cursor = utc.date(from: DateComponents(year: year, month: 1, day: 1))!
            let end = utc.date(from: DateComponents(year: year + 1, month: 1, day: 1))!
            while cursor < end {
                let matches = Occasion.allCases.filter { occasion in
                    guard let day = occasion.day(inYear: year, calendar: utc),
                          let first = utc.date(byAdding: .day, value: -(Occasion.weekLength - 1), to: day) else { return false }
                    return cursor >= first && cursor <= day
                }
                XCTAssertLessThanOrEqual(matches.count, 1, "\(cursor)")
                if !matches.isEmpty { onDays += 1 }
                cursor = utc.date(byAdding: .day, value: 1, to: cursor)!
            }
            XCTAssertEqual(onDays, 3 * Occasion.weekLength, "three weeks of seven days in \(year)")
        }
    }

    func testTheDayIsTheOneOfThePersonsOwnTimeZone() {
        // 23:30 on the 31st of October in Lima is already the 1st of November in UTC, but the event is on where the person is.
        let lima = date(2026, 10, 31, hour: 23, in: "America/Lima")
        XCTAssertEqual(Occasion.active(on: lima, calendar: calendar("America/Lima")), .halloween)
        XCTAssertNil(Occasion.active(on: lima, calendar: calendar("UTC")))
        // And just after midnight, in Lima, on the 1st: the event is over.
        let after = date(2026, 11, 1, hour: 0, in: "America/Lima")
        XCTAssertNil(Occasion.active(on: after, calendar: calendar("America/Lima")))
    }

    // MARK: The pick

    func testEachEventHasSixMarksAndSixCornersWithDistinctNames() {
        for occasion in Occasion.allCases {
            XCTAssertEqual(occasion.marks.count, 6, "\(occasion) marks")
            XCTAssertEqual(occasion.corners.count, 6, "\(occasion) corners")
            XCTAssertEqual(Set(occasion.marks).count, 6)
            XCTAssertEqual(Set(occasion.corners).count, 6)
            XCTAssertTrue(occasion.marks.allSatisfy { $0.hasPrefix("egg-\(occasion.rawValue)-mark-") })
            XCTAssertTrue(occasion.corners.allSatisfy { $0.hasPrefix("egg-\(occasion.rawValue)-corner-") })
        }
    }

    func testTheSameSeedGivesTheSamePick() {
        for occasion in Occasion.allCases {
            XCTAssertEqual(EasterEgg.pick(for: occasion, seed: 42), EasterEgg.pick(for: occasion, seed: 42))
        }
    }

    func testEverySeedGivesAPieceOfTheEventsOwnSet() {
        for occasion in Occasion.allCases {
            for seed in stride(from: UInt64(0), to: 500, by: 7) {
                let egg = EasterEgg.pick(for: occasion, seed: seed)
                XCTAssertTrue(occasion.marks.contains(egg.mark))
                XCTAssertTrue(occasion.corners.contains(egg.corner))
                XCTAssertEqual(egg.occasion, occasion)
            }
        }
    }

    func testThePickReachesEveryPieceOfASetAndNotOnlyOne() {
        for occasion in Occasion.allCases {
            let marks = Set((0 ..< 300).map { EasterEgg.pick(for: occasion, seed: UInt64($0)).mark })
            let corners = Set((0 ..< 300).map { EasterEgg.pick(for: occasion, seed: UInt64($0)).corner })
            XCTAssertEqual(marks, Set(occasion.marks), "\(occasion)")
            XCTAssertEqual(corners, Set(occasion.corners), "\(occasion)")
        }
    }

    func testTheMarkAndTheCornerAreNotAlwaysTheSamePosition() {
        let egg = (0 ..< 200).map { EasterEgg.pick(for: .halloween, seed: UInt64($0)) }
        let same = egg.filter { Occasion.halloween.marks.firstIndex(of: $0.mark) == Occasion.halloween.corners.firstIndex(of: $0.corner) }
        XCTAssertLessThan(same.count, 200, "they are picked apart")
    }

    func testAnotherCalendarOfTheMacDoesNotMoveTheWeeks() {
        // Easter 2026 is the 5th of April and Halloween the 31st of October, whatever calendar numbers the years.
        for identifier in [Calendar.Identifier.buddhist, .japanese, .islamicUmmAlQura, .hebrew, .persian] {
            var other = Calendar(identifier: identifier)
            other.timeZone = TimeZone(identifier: "UTC")!
            XCTAssertEqual(Occasion.active(on: date(2026, 4, 5), calendar: other), .easter, "\(identifier)")
            XCTAssertNil(Occasion.active(on: date(2026, 4, 9), calendar: other), "\(identifier)")
            XCTAssertEqual(Occasion.active(on: date(2026, 10, 28), calendar: other), .halloween, "\(identifier)")
            XCTAssertEqual(Occasion.active(on: date(2026, 12, 25), calendar: other), .christmas, "\(identifier)")
            XCTAssertNil(Occasion.active(on: date(2026, 6, 11), calendar: other), "\(identifier)")
        }
    }
}
