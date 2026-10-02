import Foundation

package enum ActivityKind: String, Codable, Sendable {
    case file, folder, application, volume
}

package enum ActivityEvent: String, CaseIterable, Codable, Sendable {
    case opened, saved, added, downloaded, installed, mounted

    /// English text, also used as the localization key.
    package var labelKey: String {
        switch self {
        case .opened: "Opened"
        case .saved: "Saved"
        case .added: "Added"
        case .downloaded: "Downloaded"
        case .installed: "Installed/Updated"
        case .mounted: "Connected"
        }
    }
}

package struct ActivityItem: Identifiable, Hashable, Sendable {
    package let url: URL
    package let kind: ActivityKind
    package let event: ActivityEvent
    /// nil only for volumes that were mounted before the app launched.
    package let date: Date?
    package let displayName: String
    package let parentName: String?
    package let sourceHost: String?
    /// Whether the file arrived by download, whatever happened to it since (opened, saved).
    package let isDownload: Bool

    package var id: String { url.path }

    /// iCloud Drive's folder on disk is ~/Library/Mobile Documents/com~apple~CloudDocs.
    private static func folderName(_ folder: URL) -> String {
        folder.lastPathComponent == "com~apple~CloudDocs" ? "iCloud Drive" : folder.lastPathComponent
    }

    package init(
        url: URL,
        kind: ActivityKind,
        event: ActivityEvent,
        date: Date?,
        displayName: String? = nil,
        parentName: String? = nil,
        sourceHost: String? = nil,
        isDownload: Bool = false
    ) {
        let standardized = url.standardizedFileURL
        self.url = standardized
        self.kind = kind
        self.event = event
        self.date = date
        self.displayName = displayName ?? standardized.lastPathComponent
        self.parentName = parentName ?? Self.folderName(standardized.deletingLastPathComponent())
        self.sourceHost = sourceHost
        self.isDownload = isDownload || event == .downloaded
    }
}
