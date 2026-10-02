import Foundation
import BiuBiuCore

@MainActor
enum ActivityClassifierTests {
    static let since = Date(timeIntervalSince1970: 1_000_000)
    static let downloads = "/Users/me/Downloads"
    static func at(_ offset: TimeInterval) -> Date { since.addingTimeInterval(offset) }

    static func classify(_ m: FileMetadata) -> ActivityItem? {
        ActivityClassifier.classify(m, since: since, downloadsPath: downloads)
    }

    static var tests: [TestCase] { [
        TestCase("Classifier: newest date wins and sets the event") {
            let item = classify(FileMetadata(path: "/Users/me/Documents/a.docx", isFolder: false,
                                             lastUsed: at(100), contentModified: at(500), dateAdded: at(10)))
            expectEqual(item?.event, .saved)
            expectEqual(item?.date, at(500))
            expectEqual(item?.kind, .file)
            expectEqual(item?.displayName, "a.docx")
            expectEqual(item?.parentName, "Documents")
        },
        TestCase("Classifier: opened when last-used is newest") {
            let item = classify(FileMetadata(path: "/Users/me/a.pdf", isFolder: false,
                                             lastUsed: at(900), contentModified: at(500)))
            expectEqual(item?.event, .opened)
        },
        TestCase("Classifier: nothing inside the window returns nil") {
            expect(classify(FileMetadata(path: "/Users/me/a.pdf", isFolder: false,
                                         lastUsed: at(-10), contentModified: at(-20))) == nil)
            expect(classify(FileMetadata(path: "/Users/me/a.pdf", isFolder: false)) == nil)
        },
        TestCase("Classifier: folders ignore modification date") {
            expect(classify(FileMetadata(path: "/Users/me/Proj", isFolder: true, contentModified: at(50))) == nil)
            let item = classify(FileMetadata(path: "/Users/me/Proj", isFolder: true,
                                             lastUsed: at(30), contentModified: at(50)))
            expectEqual(item?.event, .opened)
            expectEqual(item?.kind, .folder)
            expectEqual(item?.date, at(30))
        },
        TestCase("Classifier: a browser download saved straight to another folder is a download with host") {
            let item = classify(FileMetadata(path: "/Users/me/Desktop/x.zip", isFolder: false,
                                             contentCreated: at(200), contentModified: at(203), dateAdded: at(200),
                                             whereFroms: ["https://cdn.example.com/x.zip", "https://example.com/"]))
            expectEqual(item?.event, .downloaded)
            expectEqual(item?.date, at(203))
            expectEqual(item?.sourceHost, "cdn.example.com")
        },
        TestCase("Classifier: a download moved out of Downloads is added, not downloaded") {
            // Moving a file sets its date-added to the move; it was created 45 s earlier somewhere else.
            let item = classify(FileMetadata(path: "/Users/me/Desktop/stats/chart.png", isFolder: false,
                                             contentCreated: at(100), contentModified: at(100), dateAdded: at(145),
                                             whereFroms: ["https://example.com/chart.png"]))
            expectEqual(item?.event, .added)
            expectEqual(item?.date, at(145))
            expect(item?.sourceHost == nil)
        },
        TestCase("Classifier: a slow download in Downloads is a download, dated when it finished") {
            // Browsers rename "x.crdownload" in place, which keeps date-added at the start of the download.
            let item = classify(FileMetadata(path: "/Users/me/Downloads/big.zip", isFolder: false,
                                             contentCreated: at(200), contentModified: at(440), dateAdded: at(200),
                                             whereFroms: ["https://example.com/big.zip"]))
            expectEqual(item?.event, .downloaded)
            expectEqual(item?.date, at(440))
        },
        TestCase("Classifier: added inside Downloads is a download even without where-froms") {
            let item = classify(FileMetadata(path: "/Users/me/Downloads/x.zip", isFolder: false, dateAdded: at(200)))
            expectEqual(item?.event, .downloaded)
            expect(item?.sourceHost == nil)
        },
        TestCase("Classifier: Downloads prefix does not match DownloadsOld") {
            let item = classify(FileMetadata(path: "/Users/me/DownloadsOld/x.zip", isFolder: false, dateAdded: at(200)))
            expectEqual(item?.event, .added)
        },
        TestCase("Classifier: modification a moment after adding still counts as a download") {
            let item = classify(FileMetadata(path: "/Users/me/Downloads/x.pdf", isFolder: false,
                                             contentModified: at(200.4), dateAdded: at(200)))
            expectEqual(item?.event, .downloaded)
            expectEqual(item?.date, at(200.4))
        },
        TestCase("Classifier: saving a downloaded file hours later is a save") {
            let item = classify(FileMetadata(path: "/Users/me/Downloads/x.pdf", isFolder: false,
                                             contentCreated: at(200), contentModified: at(200 + 7200), dateAdded: at(200),
                                             whereFroms: ["https://a.com/x"]))
            // Still a download (it stays under Downloads), but the latest thing that happened is the save.
            expectEqual(item?.event, .saved)
            expectEqual(item?.date, at(200 + 7200))
            expect(item?.isDownload == true)
            expectEqual(item?.sourceHost, "a.com")
        },
        TestCase("Classifier: opening a download keeps it marked as a download") {
            let item = classify(FileMetadata(path: "/Users/me/Downloads/x.pdf", isFolder: false, lastUsed: at(600),
                                             contentCreated: at(200), contentModified: at(200), dateAdded: at(200),
                                             whereFroms: ["https://a.com/x.pdf"]))
            expectEqual(item?.event, .opened)
            expect(item?.isDownload == true)
            expectEqual(item?.sourceHost, "a.com")
        },
        TestCase("Classifier: a moved file is not marked as a download") {
            let item = classify(FileMetadata(path: "/Users/me/Desktop/x.png", isFolder: false,
                                             contentCreated: at(100), contentModified: at(100), dateAdded: at(145),
                                             whereFroms: ["https://a.com/x.png"]))
            expect(item?.isDownload == false)
        },
        TestCase("Classifier: a folder in Downloads is added, not downloaded, but stays in the Downloads category") {
            // An unzipped archive: folders are only ever opened or added (spec §4, item 4).
            let item = classify(FileMetadata(path: "/Users/me/Downloads/Assets", isFolder: true, dateAdded: at(200)))
            expectEqual(item?.event, .added)
            expect(item?.isDownload == true)
        },
        TestCase("Classifier: dates in the future are ignored so a real open still shows") {
            // Spotlight does return modification dates years ahead (bad camera clocks, restored backups).
            let now = at(1000)
            let item = ActivityClassifier.classify(
                FileMetadata(path: "/Users/me/a.pdf", isFolder: false, lastUsed: at(900), contentModified: at(99_999_999)),
                since: since, downloadsPath: downloads, now: now)
            expectEqual(item?.event, .opened)
            expectEqual(item?.date, at(900))
            let onlyFuture = ActivityClassifier.classify(
                FileMetadata(path: "/Users/me/b.pdf", isFolder: false, contentModified: at(99_999_999)),
                since: since, downloadsPath: downloads, now: now)
            expect(onlyFuture == nil)
            // A few seconds ahead is clock jitter, not a bad date.
            let jitter = ActivityClassifier.classify(
                FileMetadata(path: "/Users/me/c.pdf", isFolder: false, contentModified: at(1001)),
                since: since, downloadsPath: downloads, now: now)
            expectEqual(jitter?.event, .saved)
        },
        TestCase("Classifier: only downloads saved outside Downloads need a creation date") {
            expect(ActivityClassifier.needsCreationDate(path: "/Users/me/Desktop/x.zip", whereFroms: ["https://a.com/x"], downloadsPath: downloads))
            expect(!ActivityClassifier.needsCreationDate(path: "/Users/me/Downloads/x.zip", whereFroms: ["https://a.com/x"], downloadsPath: downloads))
            expect(!ActivityClassifier.needsCreationDate(path: "/Users/me/Desktop/x.zip", whereFroms: [], downloadsPath: downloads))
        },
        TestCase("Classifier: host skips where-froms that are not URLs") {
            expectEqual(ActivityClassifier.host(from: ["not a url", "https://b.org/x"]), "b.org")
            expect(ActivityClassifier.host(from: []) == nil)
        },
    ] }
}
