import Foundation
import BiuBiuCore

@MainActor
enum FolderAccessTests {
    static var tests: [TestCase] { [
        TestCase("Folder access: checks Desktop, Documents and Downloads in the home folder") {
            var asked: [String] = []
            _ = FolderAccess.readableFolders(home: "/Users/a") { asked.append($0); return true }
            expectEqual(asked, ["/Users/a/Desktop", "/Users/a/Documents", "/Users/a/Downloads"])
        },
        TestCase("Folder access: the folders that can't be read are the blocked ones") {
            let readable = FolderAccess.readableFolders(home: "/Users/a") { $0 == "/Users/a/Downloads" }
            expectEqual(readable, [.downloads])
            expectEqual(FolderAccess.blocked(readable: readable), [.desktop, .documents])
            expectEqual(FolderAccess.blocked(readable: Set(ProtectedFolder.allCases)), [])
        },
        TestCase("Folder access: the file query restarts only when a folder became readable") {
            // A home-wide Spotlight query leaves out folders it can't read and never asks for access,
            // so a query started before access was granted has to be started again.
            expect(FolderAccess.needsRestart(before: [.downloads], after: [.downloads, .desktop]))
            expect(!FolderAccess.needsRestart(before: [.downloads], after: [.downloads]))
            expect(!FolderAccess.needsRestart(before: [.downloads, .desktop], after: [.downloads]))
        },
        TestCase("Folder access: a real readable folder is reported readable") {
            let home = try makeTempDirectory()
            defer { try? FileManager.default.removeItem(at: home) }
            try FileManager.default.createDirectory(at: home.appendingPathComponent("Desktop"),
                                                    withIntermediateDirectories: false)
            expectEqual(FolderAccess.readableFolders(home: home.path), [.desktop])
        },
    ] }
}
