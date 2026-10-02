import Foundation
import BiuBiuCore

@MainActor
enum SettingsAndHotKeyTests {
    static func freshDefaults() -> UserDefaults {
        let name = "BiuBiuTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    static var tests: [TestCase] { [
        TestCase("Settings: language follows the system until the user picks one") {
            let d = freshDefaults()
            let s = AppSettings(defaults: d)
            expect(s.languageOverride == nil)
            s.languageOverride = "ja"
            expectEqual(s.languageOverride, "ja")
            // macOS picks the app's language from AppleLanguages at launch.
            expectEqual(d.stringArray(forKey: "AppleLanguages"), ["ja"])
            s.languageOverride = nil
            expect(s.languageOverride == nil)
            // Back to the system's list (the global AppleLanguages), not the app's own copy.
            expect(d.stringArray(forKey: "AppleLanguages") != ["ja"])
            d.set("xx", forKey: "languageOverride")
            expect(s.languageOverride == nil, "an unsupported language reads as following the system")
        },
        TestCase("Languages: ten languages, English first, each named in itself") {
            expectEqual(AppLanguage.supported.map(\.code),
                        ["en", "zh-Hans", "zh-Hant", "ja", "ko", "de", "fr", "es", "pt-BR", "ru"])
            expectEqual(AppLanguage.supported.first { $0.code == "ja" }?.nativeName, "日本語")
        },
        TestCase("HotKey: key names can be localized for display") {
            let combo = HotKeyCombo(keyCode: 49, modifiers: [.control, .option])
            expectEqual(combo.displayString(localizingKeyName: { $0 == "Space" ? "空格" : $0 }), "⌃⌥空格")
            expectEqual(HotKeyCombo.defaultToggle.displayString(localizingKeyName: { _ in "x" }), "⌥⌘x")
        },
        TestCase("Settings: defaults") {
            let s = AppSettings(defaults: freshDefaults())
            expectEqual(s.timeWindowDays, 7)
            expectEqual(s.lastCategory, .all)
            expectEqual(s.hotKey, .defaultToggle)
            expectEqual(s.ignoreRules, .defaults)
            expect(!s.hasSeenWelcome)
            expectEqual(s.visibleCategories, ActivityCategory.allCases)
        },
        TestCase("Settings: invalid time window falls back to 7") {
            let d = freshDefaults()
            d.set(5, forKey: "timeWindowDays")
            expectEqual(AppSettings(defaults: d).timeWindowDays, 7)
        },
        TestCase("Settings: hidden categories never hide All and reset the last category") {
            let s = AppSettings(defaults: freshDefaults())
            s.lastCategory = .apps
            s.hiddenCategories = [.all, .apps]
            expectEqual(s.hiddenCategories, [.apps])
            expectEqual(s.lastCategory, .all)
            expectEqual(s.visibleCategories, [.all, .files, .folders, .downloads, .volumes])
        },
        TestCase("Settings: hot key can be changed and cleared") {
            let s = AppSettings(defaults: freshDefaults())
            let combo = HotKeyCombo(keyCode: 49, modifiers: [.control, .option])
            s.hotKey = combo
            expectEqual(s.hotKey, combo)
            s.hotKey = nil
            expect(s.hotKey == nil)
        },
        TestCase("Settings: ignore rules round trip, corrupt data falls back to defaults") {
            let d = freshDefaults()
            let s = AppSettings(defaults: d)
            let custom = IgnoreRules(rules: [.fileExtension("log")], ignoreHidden: false)
            s.ignoreRules = custom
            expectEqual(s.ignoreRules, custom)
            d.set(Data("junk".utf8), forKey: "ignoreRules")
            expectEqual(s.ignoreRules, .defaults)
        },
        TestCase("HotKey: display string and Carbon mask") {
            let combo = HotKeyCombo(keyCode: 15, modifiers: [.command, .option, .shift, .control])
            expectEqual(combo.displayString, "⌃⌥⇧⌘R")
            expectEqual(combo.carbonModifiers, 0x0100 | 0x0200 | 0x0800 | 0x1000)
            expectEqual(HotKeyCombo.defaultToggle.displayString, "⌥⌘R")
        },
        TestCase("HotKey: requires a non-shift modifier and a known key") {
            expect(!HotKeyCombo(keyCode: 15, modifiers: []).isValid)
            expect(!HotKeyCombo(keyCode: 15, modifiers: [.shift]).isValid)
            expect(HotKeyCombo(keyCode: 15, modifiers: [.control]).isValid)
            expect(!HotKeyCombo(keyCode: 999, modifiers: [.command]).isValid)
        },
    ] }
}
