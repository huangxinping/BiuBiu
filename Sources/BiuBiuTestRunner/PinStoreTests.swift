import Foundation
import BiuBiuCore

@MainActor
enum PinStoreTests {
    static var tests: [TestCase] { [
        TestCase("PinStore: pins persist across instances, oldest first, no duplicates") {
            let dir = try makeTempDirectory()
            defer { try? FileManager.default.removeItem(at: dir) }
            let a = dir.appendingPathComponent("a.txt"), b = dir.appendingPathComponent("b.txt")
            try Data().write(to: a); try Data().write(to: b)
            var t = Date(timeIntervalSince1970: 100)
            let file = dir.appendingPathComponent("pins.json")
            let store = PinStore(fileURL: file, now: { t })
            try store.pin(url: b); t += 1
            try store.pin(url: a)
            try store.pin(url: b)
            let reloaded = PinStore(fileURL: file)
            expectEqual(reloaded.entries().map(\.displayName), ["b.txt", "a.txt"])
            expect(reloaded.isPinned(path: a.path))
        },
        TestCase("PinStore: follows a moved file and reports deleted ones as missing") {
            let dir = try makeTempDirectory()
            defer { try? FileManager.default.removeItem(at: dir) }
            let a = dir.appendingPathComponent("a.txt"), gone = dir.appendingPathComponent("gone.txt")
            try Data("x".utf8).write(to: a); try Data().write(to: gone)
            let store = PinStore(fileURL: dir.appendingPathComponent("pins.json"))
            try store.pin(url: a); try store.pin(url: gone)
            let moved = dir.appendingPathComponent("renamed.txt")
            try FileManager.default.moveItem(at: a, to: moved)
            try FileManager.default.removeItem(at: gone)
            let entries = store.entries()
            expectEqual(entries.first?.url?.path, moved.path)
            expect(store.isPinned(path: moved.path))
            expect(entries.last?.isMissing == true)
            expectEqual(entries.last?.displayName, "gone.txt")
        },
        TestCase("PinStore: a pinned file moved to the Trash counts as missing") {
            let dir = try makeTempDirectory()
            defer { try? FileManager.default.removeItem(at: dir) }
            let a = dir.appendingPathComponent("a.txt")
            try Data().write(to: a)
            let store = PinStore(fileURL: dir.appendingPathComponent("pins.json"))
            try store.pin(url: a)
            let trash = dir.appendingPathComponent(".Trash", isDirectory: true)
            try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: a, to: trash.appendingPathComponent("a.txt"))
            expect(store.entries().first?.isMissing == true)
        },
        TestCase("PinStore: unpin removes and saves") {
            let dir = try makeTempDirectory()
            defer { try? FileManager.default.removeItem(at: dir) }
            let a = dir.appendingPathComponent("a.txt")
            try Data().write(to: a)
            let file = dir.appendingPathComponent("pins.json")
            let store = PinStore(fileURL: file)
            try store.pin(url: a)
            store.unpin(path: a.path)
            expectEqual(PinStore(fileURL: file).pins.count, 0)
        },
        TestCase("PinStore: corrupt file is backed up and replaced by an empty list") {
            let dir = try makeTempDirectory()
            defer { try? FileManager.default.removeItem(at: dir) }
            let file = dir.appendingPathComponent("pins.json")
            try Data("{not json".utf8).write(to: file)
            let store = PinStore(fileURL: file, now: { Date(timeIntervalSince1970: 42) })
            expectEqual(store.pins.count, 0)
            expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("pins.corrupt-42.json").path))
            expect(!FileManager.default.fileExists(atPath: file.path))
        },
    ] }
}
