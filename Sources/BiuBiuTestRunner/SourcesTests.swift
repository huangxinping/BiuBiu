import Foundation
import BiuBiuCore

@MainActor
enum SourcesTests {
    static var tests: [TestCase] { [
        TestCase("Sources: creation dates come from the file itself, not from Spotlight") {
            // Spotlight does not provide kMDItemFSCreationDate everywhere (it was nil on the CI runner).
            let dir = try makeTempDirectory()
            defer { try? FileManager.default.removeItem(at: dir) }
            let file = dir.appendingPathComponent("x.pdf")
            try Data().write(to: file)
            let created = SpotlightFileSource.fileCreationDate(atPath: file.path)
            expect(created.map { abs($0.timeIntervalSinceNow) < 60 } == true, "got \(String(describing: created))")
            expect(SpotlightFileSource.fileCreationDate(atPath: dir.appendingPathComponent("missing").path) == nil)
        },
        TestCase("Sources: the home folder's recent files arrive within 10 seconds") {
            // Regression: reading every Spotlight result's attributes one at a time took ~35 s for
            // ~23k recent items, on the main thread, so clicks and the shortcut did nothing.
            let source = SpotlightFileSource()
            var items: [ActivityItem]?
            var status = SpotlightStatus.searching
            source.onStatus = { status = $0 }
            let start = Date()
            source.start(since: start.addingTimeInterval(-7 * 86_400)) { items = $0 }
            while items == nil, status != .noResults, Date().timeIntervalSince(start) < 15 {
                RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            }
            source.stop()
            let elapsed = Date().timeIntervalSince(start)
            // An unindexed home folder (a CI runner) is not a regression; a slow one is.
            if status == .noResults { throw SkipTest(reason: "this Mac's home folder is not in the Spotlight index") }
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
                throw SkipTest(reason: "Spotlight returned nothing for /System/Applications")
            }
            expect(records.allSatisfy { $0.path.hasPrefix("/System/Applications/") && $0.path.hasSuffix(".app") },
                   "a record is missing its path")
            expect(records.allSatisfy { $0.string(NSMetadataItemContentTypeKey) == "com.apple.application-bundle" },
                   "content type was not collected")
            expect(records.allSatisfy { $0.string(NSMetadataItemCFBundleIdentifierKey)?.isEmpty == false },
                   "bundle identifier was not collected")
        },
        TestCase("Apps: the newer of installed and opened wins, a tie goes to installed") {
            let since = Date(timeIntervalSince1970: 1_000), now = since.addingTimeInterval(10_000)
            func at(_ s: TimeInterval) -> Date { since.addingTimeInterval(s) }
            let opened = AppSource.item(path: "/Applications/Figma.app", dateAdded: at(10), lastUsed: at(500), since: since, now: now)
            expectEqual(opened?.event, .opened)
            expectEqual(opened?.date, at(500))
            expectEqual(opened?.displayName, "Figma")
            expectEqual(opened?.kind, .application)
            let updated = AppSource.item(path: "/Applications/Figma.app", dateAdded: at(900), lastUsed: at(500), since: since, now: now)
            expectEqual(updated?.event, .installed)
            let tie = AppSource.item(path: "/Applications/Figma.app", dateAdded: at(500), lastUsed: at(501), since: since, now: now)
            expectEqual(tie?.event, .installed)
            expect(AppSource.item(path: "/Applications/Old.app", dateAdded: at(-5), lastUsed: at(-9), since: since, now: now) == nil)
            expect(AppSource.item(path: "/Applications/Never.app", dateAdded: nil, lastUsed: nil, since: since, now: now) == nil)
            // A last-used date in the future is ignored; the install still counts.
            let future = AppSource.item(path: "/Applications/F.app", dateAdded: at(10), lastUsed: at(99_999_999), since: since, now: now)
            expectEqual(future?.event, .installed)
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
