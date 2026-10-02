import Foundation
import BiuBiuCore

/// Every UI string must have a Simplified Chinese translation.
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

    static var tests: [TestCase] { [
        TestCase("Localization: every privacy purpose string in Info.plist has a zh-Hans translation") {
            let plist = NSDictionary(contentsOf: packageRoot.appendingPathComponent("Resources/Info.plist")) as? [String: Any] ?? [:]
            let purposes = plist.keys.filter { $0.hasSuffix("UsageDescription") }
            expect(purposes.count >= 3, "expected Desktop/Documents/Downloads purpose strings, found \(purposes.sorted())")
            let table = NSDictionary(contentsOf: packageRoot.appendingPathComponent("Resources/zh-Hans.lproj/InfoPlist.strings"))
                as? [String: String] ?? [:]
            for key in purposes.sorted() where table[key] == nil {
                expect(false, "missing zh-Hans InfoPlist.strings entry for \(key)")
            }
        },
        TestCase("Localization: every key has a zh-Hans translation") {
            let file = packageRoot.appendingPathComponent("Resources/zh-Hans.lproj/Localizable.strings")
            guard let table = NSDictionary(contentsOf: file) as? [String: String] else {
                expect(false, "cannot read \(file.path)")
                return
            }
            let appKeys = try keysUsedInApp()
            expect(appKeys.count > 20, "found only \(appKeys.count) keys; is the regex broken?")
            for key in appKeys.union(coreKeys).sorted() where table[key] == nil {
                expect(false, "missing zh-Hans translation for \"\(key)\"")
            }
        },
    ] }
}
