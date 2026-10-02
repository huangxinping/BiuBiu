import Foundation
import BiuBiuCore

@MainActor
enum IgnoreRulesTests {
    static let home = "/Users/me"

    static var tests: [TestCase] { [
        TestCase("IgnoreRules: prefix matches the path itself and descendants") {
            let rules = IgnoreRules(rules: [.pathPrefix("~/Projects/secret")], ignoreHidden: false)
            expect(rules.isIgnored(path: "/Users/me/Projects/secret", isDirectory: true, homeDirectory: home))
            expect(rules.isIgnored(path: "/Users/me/Projects/secret/a.txt", isDirectory: false, homeDirectory: home))
            expect(!rules.isIgnored(path: "/Users/me/Projects/secret-2/a.txt", isDirectory: false, homeDirectory: home))
        },
        TestCase("IgnoreRules: file prefix does not swallow similarly named files") {
            let rules = IgnoreRules(rules: [.pathPrefix("~/Desktop/a.txt")], ignoreHidden: false)
            expect(rules.isIgnored(path: "/Users/me/Desktop/a.txt", isDirectory: false, homeDirectory: home))
            expect(!rules.isIgnored(path: "/Users/me/Desktop/a.txt.bak", isDirectory: false, homeDirectory: home))
        },
        TestCase("IgnoreRules: contains matches folders by trailing slash but not app bundles themselves") {
            let rules = IgnoreRules(rules: [.pathContains("/node_modules/"), .pathContains(".app/")], ignoreHidden: false)
            expect(rules.isIgnored(path: "/Users/me/p/node_modules", isDirectory: true, homeDirectory: home))
            expect(rules.isIgnored(path: "/Users/me/p/node_modules/x/index.js", isDirectory: false, homeDirectory: home))
            expect(!rules.isIgnored(path: "/Applications/Figma.app", isDirectory: false, homeDirectory: home))
            expect(rules.isIgnored(path: "/Applications/Figma.app/Contents/Info.plist", isDirectory: false, homeDirectory: home))
        },
        TestCase("IgnoreRules: contains ignores case and surrounding spaces") {
            let rules = IgnoreRules(rules: [.pathContains(" /Node_Modules/ ")], ignoreHidden: false)
            expect(rules.isIgnored(path: "/Users/me/p/node_modules/x.js", isDirectory: false, homeDirectory: home))
            expect(!rules.isIgnored(path: "/Users/me/p/modules/x.js", isDirectory: false, homeDirectory: home))
        },
        TestCase("IgnoreRules: extension is case-insensitive, tolerates a dot, skips folders") {
            let rules = IgnoreRules(rules: [.fileExtension(".TMP")], ignoreHidden: false)
            expect(rules.isIgnored(path: "/Users/me/x.tmp", isDirectory: false, homeDirectory: home))
            expect(rules.isIgnored(path: "/Users/me/x.Tmp", isDirectory: false, homeDirectory: home))
            expect(!rules.isIgnored(path: "/Users/me/x.tmp", isDirectory: true, homeDirectory: home))
            expect(!rules.isIgnored(path: "/Users/me/xtmp", isDirectory: false, homeDirectory: home))
        },
        TestCase("IgnoreRules: hidden switch covers any dot component") {
            var rules = IgnoreRules(rules: [], ignoreHidden: true)
            expect(rules.isIgnored(path: "/Users/me/.config/a.json", isDirectory: false, homeDirectory: home))
            expect(rules.isIgnored(path: "/Users/me/.zshrc", isDirectory: false, homeDirectory: home))
            expect(!rules.isIgnored(path: "/Users/me/notes.md", isDirectory: false, homeDirectory: home))
            expect(rules.isIgnored(path: "/Users/me/Applications/Chrome Apps.localized/Icon\r", isDirectory: false, homeDirectory: home))
            rules.ignoreHidden = false
            expect(!rules.isIgnored(path: "/Users/me/.zshrc", isDirectory: false, homeDirectory: home))
        },
        TestCase("IgnoreRules: empty values never match everything") {
            let rules = IgnoreRules(rules: [.pathPrefix(""), .pathContains("  "), .fileExtension(".")], ignoreHidden: false)
            expect(!rules.isIgnored(path: "/Users/me/a.txt", isDirectory: false, homeDirectory: home))
        },
        TestCase("IgnoreRules: defaults hide Library, trash, and in-progress downloads") {
            let rules = IgnoreRules.defaults
            expect(rules.isIgnored(path: "/Users/me/Library/Caches/x.db", isDirectory: false, homeDirectory: home))
            expect(rules.isIgnored(path: "/Users/me/Downloads/big.zip.crdownload", isDirectory: false, homeDirectory: home))
            expect(rules.isIgnored(path: "/Users/me/code/app/.git/HEAD", isDirectory: false, homeDirectory: home))
            expect(!rules.isIgnored(path: "/Users/me/Documents/report.docx", isDirectory: false, homeDirectory: home))
            expect(rules.isIgnored(path: "/Users/me/Pictures/Photos Library.photoslibrary", isDirectory: false, homeDirectory: home))
            expect(rules.isIgnored(path: "/Users/me/Music/Music/Music Library.musiclibrary/x/y.db", isDirectory: false, homeDirectory: home))
        },
        TestCase("IgnoreRules: the Library default does not hide iCloud Drive, other rules still apply") {
            let rules = IgnoreRules(rules: IgnoreRules.defaults.rules + [.pathPrefix("~/Library/Mobile Documents/com~apple~CloudDocs/Old")],
                                    ignoreHidden: true)
            expect(!rules.isIgnored(path: "/Users/me/Library/Mobile Documents/com~apple~CloudDocs/Report.pages",
                                    isDirectory: false, homeDirectory: home))
            expect(!rules.isIgnored(path: "/Users/me/Library/Mobile Documents/iCloud~com~apple~Pages/Documents/a.pages",
                                    isDirectory: false, homeDirectory: home))
            expect(rules.isIgnored(path: "/Users/me/Library/Mobile Documents/com~apple~CloudDocs/Old/a.txt",
                                   isDirectory: false, homeDirectory: home))
            expect(rules.isIgnored(path: "/Users/me/Library/Mobile Documents/com~apple~CloudDocs/x.tmp",
                                   isDirectory: false, homeDirectory: home))
            expect(rules.isIgnored(path: "/Users/me/Library/Caches/a.db", isDirectory: false, homeDirectory: home))
        },
        TestCase("IgnoreRules: abbreviate and expand home") {
            expectEqual(IgnoreRule.abbreviate("/Users/me/Desktop/a", homeDirectory: home), "~/Desktop/a")
            expectEqual(IgnoreRule.abbreviate("/Users/meow/a", homeDirectory: home), "/Users/meow/a")
            expectEqual(IgnoreRule.expand("~/Desktop", homeDirectory: home), "/Users/me/Desktop")
            expectEqual(IgnoreRule.expand("~", homeDirectory: home), "/Users/me")
        },
        TestCase("IgnoreRules: survives a JSON round trip") {
            let data = try JSONEncoder().encode(IgnoreRules.defaults)
            expectEqual(try JSONDecoder().decode(IgnoreRules.self, from: data), IgnoreRules.defaults)
        },
    ] }
}
