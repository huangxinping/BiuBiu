import Foundation

/// The Spotlight attributes BiuBiu needs for one file or folder.
package struct FileMetadata: Sendable {
    package var path: String
    package var isFolder: Bool
    package var lastUsed: Date?
    package var contentModified: Date?
    package var dateAdded: Date?
    package var whereFroms: [String]

    package init(
        path: String,
        isFolder: Bool,
        lastUsed: Date? = nil,
        contentModified: Date? = nil,
        dateAdded: Date? = nil,
        whereFroms: [String] = []
    ) {
        self.path = path
        self.isFolder = isFolder
        self.lastUsed = lastUsed
        self.contentModified = contentModified
        self.dateAdded = dateAdded
        self.whereFroms = whereFroms
    }
}

package enum ActivityClassifier {
    /// Dates this close to the newest one count as a tie. Browsers often write the
    /// modification date a few milliseconds after the file lands in Downloads.
    package static let tieTolerance: TimeInterval = 2

    /// Turns Spotlight metadata into an activity, or nil when nothing happened since `since`.
    package static func classify(_ m: FileMetadata, since: Date, downloadsPath: String) -> ActivityItem? {
        // Order is the tie-break priority: added beats saved beats opened.
        var candidates: [(ActivityEvent, Date)] = []
        if let d = m.dateAdded { candidates.append((.added, d)) }
        if !m.isFolder, let d = m.contentModified { candidates.append((.saved, d)) }
        if let d = m.lastUsed { candidates.append((.opened, d)) }

        guard let newest = candidates.map(\.1).max(), newest >= since else { return nil }
        let event = candidates.first { newest.timeIntervalSince($0.1) <= tieTolerance }!.0

        let downloadsPrefix = downloadsPath.hasSuffix("/") ? downloadsPath : downloadsPath + "/"
        let isDownload = event == .added && (!m.whereFroms.isEmpty || m.path.hasPrefix(downloadsPrefix))

        return ActivityItem(
            url: URL(fileURLWithPath: m.path, isDirectory: m.isFolder),
            kind: m.isFolder ? .folder : .file,
            event: isDownload ? .downloaded : event,
            date: newest,
            sourceHost: isDownload ? host(from: m.whereFroms) : nil
        )
    }

    package static func host(from whereFroms: [String]) -> String? {
        for string in whereFroms {
            if let host = URL(string: string)?.host(), !host.isEmpty { return host }
        }
        return nil
    }
}
