import Foundation
import BiuBiuCore

@MainActor
enum PinStoreTests {
    static var tests: [TestCase] { [
        TestCase("PinStore: entries are cached until resolved again or the pins change") {
            let dir = try makeTempDirectory()
            defer { try? FileManager.default.removeItem(at: dir) }
            let a = dir.appendingPathComponent("a.txt"), b = dir.appendingPathComponent("b.txt")
            try Data().write(to: a); try Data().write(to: b)
            let store = PinStore(fileURL: dir.appendingPathComponent("pins.json"))
            try store.pin(url: a)
            expectEqual(store.resolveEntries().first?.displayName, "a.txt")
            try FileManager.default.moveItem(at: a, to: dir.appendingPathComponent("moved.txt"))
            expectEqual(store.entries.first?.displayName, "a.txt")
            expectEqual(store.resolveEntries().first?.displayName, "moved.txt")
            try store.pin(url: b)
            expectEqual(store.entries.map(\.displayName), ["moved.txt", "b.txt"])
        },
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
            expectEqual(reloaded.resolveEntries().map(\.displayName), ["b.txt", "a.txt"])
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
            let entries = store.resolveEntries()
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
            expect(store.resolveEntries().first?.isMissing == true)
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
        TestCase("PinStore: pinning a renamed file again does not duplicate it, and toggling unpins it") {
            // The panel shows the new name from Spotlight while the pin still remembers the old path.
            let dir = try makeTempDirectory()
            defer { try? FileManager.default.removeItem(at: dir) }
            let a = dir.appendingPathComponent("a.txt"), renamed = dir.appendingPathComponent("renamed.txt")
            try Data("x".utf8).write(to: a)
            let store = PinStore(fileURL: dir.appendingPathComponent("pins.json"))
            try store.pin(url: a)
            try FileManager.default.moveItem(at: a, to: renamed)
            try store.pin(url: renamed)
            expectEqual(store.pins.count, 1)
            expectEqual(store.pins.first?.path, renamed.path)
            expectEqual(try store.togglePin(url: renamed), false)
            expectEqual(store.pins.count, 0)
            expectEqual(try store.togglePin(url: renamed), true)
            expectEqual(store.pins.count, 1)
        },
        TestCase("PinStore: an unreadable pins file is never overwritten") {
            let dir = try makeTempDirectory()
            defer { try? FileManager.default.removeItem(at: dir) }
            let file = dir.appendingPathComponent("pins.json")
            let original = Data("[]".utf8)
            try original.write(to: file)
            try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: file.path)
            defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: file.path) }
            let a = dir.appendingPathComponent("a.txt")
            try Data().write(to: a)
            let store = PinStore(fileURL: file)
            expectEqual(store.pins.count, 0)
            try store.pin(url: a)
            try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: file.path)
            expectEqual(try Data(contentsOf: file), original)
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
