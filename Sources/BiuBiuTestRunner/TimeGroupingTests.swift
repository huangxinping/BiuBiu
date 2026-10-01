import Foundation
import BiuBiuCore

@MainActor
enum TimeGroupingTests {
    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return c
    }

    static func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
    }

    static func group(_ d: Date, now: Date) -> TimeGroup { TimeGroup.group(for: d, now: now, calendar: calendar) }

    static var tests: [TestCase] { [
        TestCase("TimeGroup: within an hour is just now, even across midnight") {
            let now = date(2026, 10, 1, 0, 30)
            expectEqual(group(date(2026, 9, 30, 23, 50), now: now), .justNow)
            expectEqual(group(now.addingTimeInterval(120), now: now), .justNow)
        },
        TestCase("TimeGroup: today, yesterday, this week, earlier") {
            let now = date(2026, 10, 8, 15, 0)
            expectEqual(group(date(2026, 10, 8, 9, 0), now: now), .today)
            expectEqual(group(date(2026, 10, 7, 23, 59), now: now), .yesterday)
            expectEqual(group(date(2026, 10, 7, 0, 0), now: now), .yesterday)
            expectEqual(group(date(2026, 10, 6, 23, 59), now: now), .thisWeek)
            expectEqual(group(date(2026, 10, 2, 0, 0), now: now), .thisWeek)
            expectEqual(group(date(2026, 10, 1, 23, 59), now: now), .earlier)
        },
    ] }
}
