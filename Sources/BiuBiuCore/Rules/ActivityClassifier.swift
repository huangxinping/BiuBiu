import Foundation

/// The Spotlight attributes BiuBiu needs for one file or folder.
package struct FileMetadata: Sendable {
    package var path: String
    package var isFolder: Bool
    package var lastUsed: Date?
    package var contentCreated: Date?
    package var contentModified: Date?
    package var dateAdded: Date?
    package var whereFroms: [String]

    package init(
        path: String,
        isFolder: Bool,
        lastUsed: Date? = nil,
        contentCreated: Date? = nil,
        contentModified: Date? = nil,
        dateAdded: Date? = nil,
        whereFroms: [String] = []
    ) {
        self.path = path
        self.isFolder = isFolder
        self.lastUsed = lastUsed
        self.contentCreated = contentCreated
        self.contentModified = contentModified
        self.dateAdded = dateAdded
        self.whereFroms = whereFroms
    }
}

package enum ActivityClassifier {
    /// Dates this close to the newest one count as a tie. Browsers often write the
    /// modification date a few milliseconds after the file lands in Downloads.
    package static let tieTolerance: TimeInterval = 2

    /// A write this long after a download arrived is a later edit, not the download finishing.
    package static let downloadWindow: TimeInterval = 3600

    /// Whether `isDownload` will need `contentCreated`: only a file with a download source that was saved
    /// somewhere other than Downloads. Sources ask before paying for a stat.
    package static func needsCreationDate(path: String, whereFroms: [String], downloadsPath: String) -> Bool {
        !whereFroms.isEmpty && !path.hasPrefix(downloadsPrefix(downloadsPath))
    }

    private static func downloadsPrefix(_ downloadsPath: String) -> String {
        downloadsPath.hasSuffix("/") ? downloadsPath : downloadsPath + "/"
    }

    /// Turns Spotlight metadata into an activity, or nil when nothing happened since `since`.
    /// Dates after `now` (plus a little clock jitter) are bad data and are ignored, so a file whose
    /// modification date is years ahead still shows up when it is really opened.
    package static func classify(_ m: FileMetadata, since: Date, downloadsPath: String, now: Date = Date()) -> ActivityItem? {
        var m = m
        let latestPlausible = now.addingTimeInterval(tieTolerance)
        func plausible(_ date: Date?) -> Date? { date.flatMap { $0 <= latestPlausible ? $0 : nil } }
        m.lastUsed = plausible(m.lastUsed)
        m.contentModified = plausible(m.contentModified)
        m.dateAdded = plausible(m.dateAdded)

        let downloadsPrefix = downloadsPrefix(downloadsPath)
        // Order is the tie-break priority: added (or downloaded) beats saved beats opened.
        let download = m.dateAdded != nil && isDownload(m, downloadsPrefix: downloadsPrefix)
        var candidates: [(ActivityEvent, Date)] = []
        if let added = m.dateAdded {
            // Folders are only ever opened or added; one in Downloads still belongs to that category.
            if download, !m.isFolder {
                // Browsers rename "x.crdownload" in place, so date-added marks the start of the download
                // and the last write marks its end.
                let finished = m.contentModified.flatMap { modified in
                    modified > added && modified.timeIntervalSince(added) <= downloadWindow ? modified : nil
                }
                candidates.append((.downloaded, finished ?? added))
            } else {
                candidates.append((.added, added))
            }
        }
        if !m.isFolder, let d = m.contentModified { candidates.append((.saved, d)) }
        if let d = m.lastUsed { candidates.append((.opened, d)) }

        guard let newest = candidates.map(\.1).max(), newest >= since else { return nil }
        let event = candidates.first { newest.timeIntervalSince($0.1) <= tieTolerance }!.0

        return ActivityItem(
            url: URL(fileURLWithPath: m.path, isDirectory: m.isFolder),
            kind: m.isFolder ? .folder : .file,
            event: event,
            date: newest,
            sourceHost: download ? host(from: m.whereFroms) : nil,
            isDownload: download
        )
    }

    /// Anything in Downloads, however it got there, plus files a browser saved straight into another
    /// folder. A download the user later moved elsewhere was created well before it was added to its
    /// current folder, so it no longer counts.
    private static func isDownload(_ m: FileMetadata, downloadsPrefix: String) -> Bool {
        if m.path.hasPrefix(downloadsPrefix) { return true }
        guard !m.isFolder, !m.whereFroms.isEmpty, let created = m.contentCreated, let added = m.dateAdded else {
            return false
        }
        return abs(added.timeIntervalSince(created)) <= tieTolerance
    }

    package static func host(from whereFroms: [String]) -> String? {
        for string in whereFroms {
            if let host = URL(string: string)?.host(), !host.isEmpty { return host }
        }
        return nil
    }
}
