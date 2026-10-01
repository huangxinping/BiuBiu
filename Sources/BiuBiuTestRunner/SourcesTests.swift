import Foundation
import BiuBiuCore

@MainActor
enum SourcesTests {
    static var tests: [TestCase] { [
        TestCase("Sources: the home folder's recent files arrive within 10 seconds") {
            // Regression: reading every Spotlight result's attributes one at a time took ~35 s for
            // ~23k recent items, on the main thread, so clicks and the shortcut did nothing.
            let source = SpotlightFileSource()
            var items: [ActivityItem]?
            let start = Date()
            source.start(since: start.addingTimeInterval(-7 * 86_400)) { items = $0 }
            while items == nil, Date().timeIntervalSince(start) < 15 {
                RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            }
            source.stop()
            let elapsed = Date().timeIntervalSince(start)
            expect(items != nil, "no results after \(Int(elapsed)) s")
            expect(elapsed < 10, "first results took \(String(format: "%.1f", elapsed)) s")
        },
        TestCase("Sources: Spotlight records carry their path and every declared attribute") {
            let runner = MetadataQueryRunner()
            var records: [MetadataRecord]?
            runner.start(
                predicate: NSPredicate(format: "%K == 'com.apple.application-bundle'", NSMetadataItemContentTypeKey),
                scopes: [URL(fileURLWithPath: "/System/Applications")],
                attributes: [NSMetadataItemContentTypeKey, NSMetadataItemCFBundleIdentifierKey],
                onResults: { records = $0 },
                onStatus: { _ in }
            )
            let start = Date()
            while records == nil, Date().timeIntervalSince(start) < 15 {
                RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            }
            runner.stop()
            guard let records, !records.isEmpty else {
                print("    skipped: Spotlight returned nothing for /System/Applications")
                return
            }
            expect(records.allSatisfy { $0.path.hasPrefix("/System/Applications/") && $0.path.hasSuffix(".app") },
                   "a record is missing its path")
            expect(records.allSatisfy { $0.string(NSMetadataItemContentTypeKey) == "com.apple.application-bundle" },
                   "content type was not collected")
            expect(records.allSatisfy { $0.string(NSMetadataItemCFBundleIdentifierKey)?.isEmpty == false },
                   "bundle identifier was not collected")
        },
        TestCase("Sources: apps in ~/Applications are left to the app source, others stay files") {
            let apps = "/Users/me/Applications/"
            expect(SpotlightFileSource.isLeftToAppSource(contentType: "com.apple.application-bundle",
                                                         path: "/Users/me/Applications/Chrome Apps.localized/Gmail.app",
                                                         userApplicationsPath: apps))
            expect(!SpotlightFileSource.isLeftToAppSource(contentType: "com.apple.application-bundle",
                                                          path: "/Users/me/Downloads/Tool.app", userApplicationsPath: apps))
            expect(!SpotlightFileSource.isLeftToAppSource(contentType: "public.plain-text",
                                                          path: "/Users/me/Applications/readme.txt", userApplicationsPath: apps))
        },
        TestCase("Volumes: only external volumes, mount date when known") {
            let root = VolumeInfo(url: URL(fileURLWithPath: "/"), name: "Macintosh HD", isRemovable: false,
                                  isEjectable: false, isLocal: true, isRootFileSystem: true)
            let usb = VolumeInfo(url: URL(fileURLWithPath: "/Volumes/T7"), name: "T7", isRemovable: true,
                                 isEjectable: true, isLocal: true, isRootFileSystem: false)
            let nas = VolumeInfo(url: URL(fileURLWithPath: "/Volumes/share"), name: "share", isRemovable: false,
                                 isEjectable: false, isLocal: false, isRootFileSystem: false)
            let internalData = VolumeInfo(url: URL(fileURLWithPath: "/Volumes/Data2"), name: "Data2", isRemovable: false,
                                          isEjectable: false, isLocal: true, isRootFileSystem: false)
            let mounted = Date(timeIntervalSince1970: 5)
            let items = VolumeSource.items(from: [root, usb, nas, internalData], mountDates: ["/Volumes/T7": mounted])
            expectEqual(items.map(\.displayName), ["T7", "share"])
            expectEqual(items.first?.date, mounted)
            expect(items.last?.date == nil)
            expectEqual(items.first?.kind, .volume)
        },
    ] }
}
