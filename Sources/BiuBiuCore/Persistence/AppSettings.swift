import Foundation

@MainActor
package final class AppSettings {
    package static let timeWindowOptions = [1, 3, 7, 14, 30]
    package static let defaultTimeWindowDays = 7

    private enum Key {
        static let timeWindowDays = "timeWindowDays"
        static let hiddenCategories = "hiddenCategories"
        static let lastCategory = "lastCategory"
        static let hasSeenWelcome = "hasSeenWelcome"
        static let hotKey = "hotKey"
        static let hotKeyDisabled = "hotKeyDisabled"
        static let ignoreRules = "ignoreRules"
        static let pinnedCollapsed = "pinnedCollapsed"
    }

    private let defaults: UserDefaults

    package init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    package var timeWindowDays: Int {
        get {
            let stored = defaults.integer(forKey: Key.timeWindowDays)
            return Self.timeWindowOptions.contains(stored) ? stored : Self.defaultTimeWindowDays
        }
        set { defaults.set(newValue, forKey: Key.timeWindowDays) }
    }

    /// Categories the user switched off. `.all` can never be hidden.
    package var hiddenCategories: Set<ActivityCategory> {
        get {
            let raw = defaults.stringArray(forKey: Key.hiddenCategories) ?? []
            return Set(raw.compactMap(ActivityCategory.init(rawValue:))).subtracting([.all])
        }
        set { defaults.set(newValue.subtracting([.all]).map(\.rawValue).sorted(), forKey: Key.hiddenCategories) }
    }

    package var visibleCategories: [ActivityCategory] {
        let hidden = hiddenCategories
        return ActivityCategory.allCases.filter { !hidden.contains($0) }
    }

    package var lastCategory: ActivityCategory {
        get {
            let stored = defaults.string(forKey: Key.lastCategory).flatMap(ActivityCategory.init(rawValue:)) ?? .all
            return hiddenCategories.contains(stored) ? .all : stored
        }
        set { defaults.set(newValue.rawValue, forKey: Key.lastCategory) }
    }

    package var hasSeenWelcome: Bool {
        get { defaults.bool(forKey: Key.hasSeenWelcome) }
        set { defaults.set(newValue, forKey: Key.hasSeenWelcome) }
    }

    package var pinnedCollapsed: Bool {
        get { defaults.bool(forKey: Key.pinnedCollapsed) }
        set { defaults.set(newValue, forKey: Key.pinnedCollapsed) }
    }

    /// nil means the user cleared the shortcut. Defaults to ⌥⌘R.
    package var hotKey: HotKeyCombo? {
        get {
            if defaults.bool(forKey: Key.hotKeyDisabled) { return nil }
            guard let data = defaults.data(forKey: Key.hotKey),
                  let combo = try? JSONDecoder().decode(HotKeyCombo.self, from: data),
                  combo.isValid else { return .defaultToggle }
            return combo
        }
        set {
            if let combo = newValue {
                defaults.set(false, forKey: Key.hotKeyDisabled)
                defaults.set(try? JSONEncoder().encode(combo), forKey: Key.hotKey)
            } else {
                defaults.set(true, forKey: Key.hotKeyDisabled)
            }
        }
    }

    package var ignoreRules: IgnoreRules {
        get {
            guard let data = defaults.data(forKey: Key.ignoreRules),
                  let rules = try? JSONDecoder().decode(IgnoreRules.self, from: data) else { return .defaults }
            return rules
        }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: Key.ignoreRules) }
    }
}
