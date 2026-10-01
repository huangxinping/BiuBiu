import Foundation

/// The second line of a timeline row, from already-localized pieces.
package enum ItemSubtitle {
    package static let pinMark = "📌"

    /// "📌 Documents · Saved · 2 min ago": a pin mark when pinned (so pins show in every category, not
    /// only in All's pinned section), the parent folder for files and folders, the event, and when.
    package static func compose(item: ActivityItem, isPinned: Bool, eventLabel: String, relativeTime: String?) -> String {
        var parts: [String] = []
        if item.kind == .file || item.kind == .folder, let parent = item.parentName, !parent.isEmpty {
            parts.append(parent)
        }
        parts.append(eventLabel)
        if let relativeTime { parts.append(relativeTime) }
        let text = parts.joined(separator: " · ")
        return isPinned ? "\(pinMark) \(text)" : text
    }
}
