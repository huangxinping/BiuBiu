import Foundation

/// The segments at the top of the panel.
package enum ActivityCategory: String, CaseIterable, Codable, Sendable {
    case all, files, folders, downloads, apps, volumes

    package var titleKey: String {
        switch self {
        case .all: "All"
        case .files: "Files"
        case .folders: "Folders"
        case .downloads: "Downloads"
        case .apps: "Apps"
        case .volumes: "Disks"
        }
    }

    package func includes(_ item: ActivityItem) -> Bool {
        switch self {
        // Apps are launched many times a day; those entries would bury the files in the timeline.
        case .all: item.date != nil && !(item.kind == .application && item.event == .opened)
        case .files: item.kind == .file
        case .folders: item.kind == .folder
        case .downloads: item.isDownload
        case .apps: item.kind == .application
        case .volumes: item.kind == .volume
        }
    }
}
