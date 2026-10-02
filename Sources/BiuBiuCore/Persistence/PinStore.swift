import Foundation

package struct Pin: Codable, Hashable, Sendable {
    package var bookmark: Data
    /// Last known path; refreshed when the bookmark resolves somewhere new.
    package var path: String
    package var pinnedAt: Date

    package init(bookmark: Data, path: String, pinnedAt: Date) {
        self.bookmark = bookmark
        self.path = path
        self.pinnedAt = pinnedAt
    }
}

/// A pin plus where it currently lives. `url` is nil when the item can no longer be found.
package struct PinnedEntry: Hashable, Sendable {
    package let pin: Pin
    package let url: URL?

    package init(pin: Pin, url: URL?) {
        self.pin = pin
        self.url = url
    }

    package var displayName: String { ((url?.path ?? pin.path) as NSString).lastPathComponent }
    package var isMissing: Bool { url == nil }
}

@MainActor
package final class PinStore {
    package private(set) var pins: [Pin] = []
    private let fileURL: URL
    private var cachedEntries: [PinnedEntry]?
    private let now: () -> Date

    package static func defaultFileURL() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("BiuBiu", isDirectory: true).appendingPathComponent("pins.json")
    }

    package init(fileURL: URL, now: @escaping () -> Date = Date.init) {
        self.fileURL = fileURL
        self.now = now
        load()
    }

    package func isPinned(path: String) -> Bool {
        pins.contains { $0.path == path }
    }

    package func pin(url: URL) throws {
        let path = url.standardizedFileURL.path
        guard !isPinned(path: path) else { return }
        let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        pins.append(Pin(bookmark: bookmark, path: path, pinnedAt: now()))
        cachedEntries = nil
        save()
    }

    package func unpin(path: String) {
        pins.removeAll { $0.path == path }
        cachedEntries = nil
        save()
    }

    /// Every pin, oldest first. `refresh` resolves the bookmarks again (following moves); otherwise the last
    /// resolution is reused, so typing in the search field does not touch the disk for every pin.
    package func entries(refresh: Bool = true) -> [PinnedEntry] {
        if !refresh, let cachedEntries { return cachedEntries }
        var changed = false
        let result = pins.indices.map { index -> PinnedEntry in
            var pin = pins[index]
            var isStale = false
            guard let url = try? URL(resolvingBookmarkData: pin.bookmark, options: [.withoutUI, .withoutMounting],
                                     relativeTo: nil, bookmarkDataIsStale: &isStale),
                  FileManager.default.fileExists(atPath: url.path),
                  !Self.isInTrash(url) else {
                return PinnedEntry(pin: pin, url: nil)
            }
            let resolvedPath = url.standardizedFileURL.path
            if resolvedPath != pin.path || isStale {
                pin.path = resolvedPath
                if let fresh = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
                    pin.bookmark = fresh
                }
                pins[index] = pin
                changed = true
            }
            return PinnedEntry(pin: pin, url: url.standardizedFileURL)
        }
        if changed { save() }
        cachedEntries = result
        return result
    }

    /// Deleting in Finder moves to the Trash; the bookmark follows, but the file is gone for the user.
    private static func isInTrash(_ url: URL) -> Bool {
        url.pathComponents.contains { $0 == ".Trash" || $0 == ".Trashes" }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            pins = try JSONDecoder().decode([Pin].self, from: data)
        } catch {
            let stamp = Int(now().timeIntervalSince1970)
            let backup = fileURL.deletingLastPathComponent().appendingPathComponent("pins.corrupt-\(stamp).json")
            try? FileManager.default.moveItem(at: fileURL, to: backup)
            Log.persistence.error("pins.json unreadable, moved to \(backup.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            pins = []
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(pins).write(to: fileURL, options: .atomic)
        } catch {
            Log.persistence.error("Saving pins failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
