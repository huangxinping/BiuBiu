import Foundation
import BiuBiuCore

@MainActor
enum ModelTests {
    static func item(_ path: String, kind: ActivityKind = .file, event: ActivityEvent = .saved,
                     date: Date? = Date()) -> ActivityItem {
        ActivityItem(url: URL(fileURLWithPath: path), kind: kind, event: event, date: date)
    }

    static var tests: [TestCase] { [
        TestCase("Model: item derives name, parent and a standardized id") {
            let a = item("/Users/me/Desktop/../Documents/report.pdf")
            expectEqual(a.displayName, "report.pdf")
            expectEqual(a.parentName, "Documents")
            expectEqual(a.id, "/Users/me/Documents/report.pdf")
        },
        TestCase("Model: explicit display name wins") {
            let app = ActivityItem(url: URL(fileURLWithPath: "/Applications/Figma.app"), kind: .application,
                                   event: .installed, date: Date(), displayName: "Figma")
            expectEqual(app.displayName, "Figma")
        },
        TestCase("Model: categories include the right items") {
            let file = item("/a.txt")
            let folder = item("/p", kind: .folder, event: .opened)
            let download = item("/Users/me/Downloads/x.zip", event: .downloaded)
            let app = item("/Applications/X.app", kind: .application, event: .installed)
            let dated = item("/Volumes/T7", kind: .volume, event: .mounted)
            let undated = item("/Volumes/T8", kind: .volume, event: .mounted, date: nil)
            let all = [file, folder, download, app, dated, undated]
            expectEqual(all.filter(ActivityCategory.all.includes).count, 5)
            expectEqual(all.filter(ActivityCategory.files.includes), [file, download])
            expectEqual(all.filter(ActivityCategory.folders.includes), [folder])
            expectEqual(all.filter(ActivityCategory.downloads.includes), [download])
            expectEqual(all.filter(ActivityCategory.apps.includes), [app])
            expectEqual(all.filter(ActivityCategory.volumes.includes), [dated, undated])
        },
    ] }
}
