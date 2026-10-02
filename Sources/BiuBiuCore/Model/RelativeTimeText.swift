import Foundation

package enum RelativeTimeText {
    /// "5 min. ago" in the given app localization (e.g. "zh-Hans"), or nil under a minute, where the UI
    /// says "now". Following the app's language keeps the time in the same language as the labels around it.
    package static func string(for date: Date, now: Date, localization: String) -> String? {
        guard now.timeIntervalSince(date) >= 60 else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: localization)
        return formatter.localizedString(for: date, relativeTo: now)
    }
}
