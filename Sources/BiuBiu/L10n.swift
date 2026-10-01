import Foundation

/// Looks up a UI string. Keys are the English text, so a missing translation still reads fine.
func L(_ key: String) -> String {
    Bundle.main.localizedString(forKey: key, value: key, table: nil)
}

@MainActor
enum RelativeTime {
    private static let formatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    static func string(for date: Date, now: Date = Date()) -> String {
        now.timeIntervalSince(date) < 60 ? L("now") : formatter.localizedString(for: date, relativeTo: now)
    }
}
