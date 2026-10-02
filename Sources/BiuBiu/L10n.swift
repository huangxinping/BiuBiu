import Foundation
import BiuBiuCore

/// Looks up a UI string. Keys are the English text, so a missing translation still reads fine.
func L(_ key: String) -> String {
    Bundle.main.localizedString(forKey: key, value: key, table: nil)
}

enum RelativeTime {
    /// The language the UI is shown in, so times match the labels around them.
    static var localization: String { Bundle.main.preferredLocalizations.first ?? "en" }

    static func string(for date: Date, now: Date = Date()) -> String {
        RelativeTimeText.string(for: date, now: now, localization: localization) ?? L("now")
    }
}

extension HotKeyCombo {
    /// The shortcut as shown in the UI, with key names such as "Space" translated.
    var localizedDisplayString: String { displayString(localizingKeyName: L) }
}
