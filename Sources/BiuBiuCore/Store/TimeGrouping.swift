import Foundation

package enum TimeGroup: Int, CaseIterable, Comparable, Sendable {
    case justNow, today, yesterday, thisWeek, earlier

    package var titleKey: String {
        switch self {
        case .justNow: "Just Now"
        case .today: "Today"
        case .yesterday: "Yesterday"
        case .thisWeek: "This Week"
        case .earlier: "Earlier"
        }
    }

    package static func < (lhs: TimeGroup, rhs: TimeGroup) -> Bool { lhs.rawValue < rhs.rawValue }

    package static func group(for date: Date, now: Date, calendar: Calendar) -> TimeGroup {
        if now.timeIntervalSince(date) < 3600 { return .justNow }
        if calendar.isDate(date, inSameDayAs: now) { return .today }
        let startOfToday = calendar.startOfDay(for: now)
        if let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday),
           date >= startOfYesterday {
            return .yesterday
        }
        if let weekStart = calendar.date(byAdding: .day, value: -6, to: startOfToday), date >= weekStart {
            return .thisWeek
        }
        return .earlier
    }
}
