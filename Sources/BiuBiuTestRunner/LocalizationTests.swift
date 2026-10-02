import Foundation
import BiuBiuCore

/// Every UI string must be translated, with the same placeholders, in every language the app ships.
@MainActor
enum LocalizationTests {
    static let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    static func keysUsedInApp() throws -> Set<String> {
        let sources = packageRoot.appendingPathComponent("Sources/BiuBiu")
        let regex = try NSRegularExpression(pattern: #"\bL\("((?:[^"\\]|\\.)*)"\)"#)
        var keys: Set<String> = []
        let files = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)
        while let file = files?.nextObject() as? URL {
            guard file.pathExtension == "swift" else { continue }
            let text = try String(contentsOf: file, encoding: .utf8)
            for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                keys.insert(String(text[Range(match.range(at: 1), in: text)!]))
            }
        }
        return keys
    }

    static var coreKeys: Set<String> {
        Set(ActivityEvent.allCases.map(\.labelKey)
            + ActivityCategory.allCases.map(\.titleKey)
            + TimeGroup.allCases.map(\.titleKey)
            + [SectionKind.connected.titleKey]
            + ["Space"])  // HotKeyCombo key name, translated through L in the app
    }

    static func table(_ language: String, _ name: String) -> [String: String]? {
        NSDictionary(contentsOf: packageRoot.appendingPathComponent("Resources/\(language).lproj/\(name).strings"))
            as? [String: String]
    }

    /// Format placeholders in order of appearance, positional ones ("%1$@") normalized to "%@".
    static func placeholders(_ text: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: #"%(?:\d+\$)?([@dlu]+)"#)
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            .map { "%" + String(text[Range($0.range(at: 1), in: text)!]) }
            .sorted()
    }

    static var translatedLanguages: [String] { AppLanguage.supported.map(\.code).filter { $0 != "en" } }

    static var tests: [TestCase] { [
        TestCase("Localization: the app declares exactly the languages it ships") {
            let plist = NSDictionary(contentsOf: packageRoot.appendingPathComponent("Resources/Info.plist")) as? [String: Any] ?? [:]
            let declared = Set(plist["CFBundleLocalizations"] as? [String] ?? [])
            let folders = try FileManager.default.contentsOfDirectory(atPath: packageRoot.appendingPathComponent("Resources").path)
            let shipped = Set(folders.filter { $0.hasSuffix(".lproj") }.map { String($0.dropLast(6)) })
            let supported = Set(AppLanguage.supported.map(\.code))
            expectEqual(declared, supported)
            expectEqual(shipped, supported)
        },
        TestCase("Localization: every key is translated in every language, with the same placeholders") {
            let appKeys = try keysUsedInApp()
            expect(appKeys.count > 20, "found only \(appKeys.count) keys; is the regex broken?")
            let keys = appKeys.union(coreKeys).sorted()
            for language in translatedLanguages {
                guard let table = table(language, "Localizable") else {
                    expect(false, "cannot read \(language).lproj/Localizable.strings")
                    continue
                }
                let missing = keys.filter { table[$0] == nil }
                expect(missing.isEmpty, "\(language) is missing \(missing.count): \(missing.prefix(3))")
                for key in keys {
                    if let value = table[key], placeholders(value) != placeholders(key) {
                        expect(false, "\(language): \"\(value)\" has placeholders \(placeholders(value)), key has \(placeholders(key))")
                    }
                }
            }
        },
        TestCase("Localization: every privacy purpose string is translated in every language") {
            let plist = NSDictionary(contentsOf: packageRoot.appendingPathComponent("Resources/Info.plist")) as? [String: Any] ?? [:]
            let purposes = plist.keys.filter { $0.hasSuffix("UsageDescription") }.sorted()
            expect(purposes.count >= 3, "expected Desktop/Documents/Downloads purpose strings, found \(purposes)")
            for language in AppLanguage.supported.map(\.code) {
                let table = table(language, "InfoPlist") ?? [:]
                let missing = purposes.filter { table[$0] == nil }
                expect(missing.isEmpty, "\(language).lproj/InfoPlist.strings is missing \(missing)")
            }
        },
        TestCase("Localization: placeholder check sees through positional arguments") {
            expectEqual(placeholders("Couldn’t eject “%@”: %@"), ["%@", "%@"])
            expectEqual(placeholders("无法推出“%1$@”：%2$@"), ["%@", "%@"])
            expectEqual(placeholders("%d days"), ["%d"])
        },
    ] }
}
