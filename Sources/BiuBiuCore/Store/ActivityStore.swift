import Foundation

package enum SectionKind: Hashable, Sendable {
    /// Volumes without a mount time, shown first in the Disks category.
    case connected
    case time(TimeGroup)

    package var titleKey: String {
        switch self {
        case .connected: "Connected"
        case .time(let group): group.titleKey
        }
    }
}

package struct TimelineSection: Hashable, Sendable {
    package let kind: SectionKind
    package let items: [ActivityItem]

    package init(kind: SectionKind, items: [ActivityItem]) {
        self.kind = kind
        self.items = items
    }
}

@MainActor
package final class ActivityStore {
    package var ignoreRules: IgnoreRules { didSet { recompute() } }
    package var timeWindowDays: Int { didSet { onChange?() } }
    package var category: ActivityCategory = .all { didSet { onChange?() } }
    package var searchText = "" { didSet { onChange?() } }
    package var onChange: (() -> Void)?

    /// Merged, de-duplicated, ignore-filtered, newest first. Not capped, so every category keeps its items.
    package private(set) var allItems: [ActivityItem] = []

    private var itemsBySource: [String: [ActivityItem]] = [:]
    private var removedAt: [String: Date] = [:]
    private let homeDirectory: String
    private let maxItems: Int
    private let now: () -> Date
    private let calendar: Calendar

    package init(
        ignoreRules: IgnoreRules,
        timeWindowDays: Int,
        homeDirectory: String,
        maxItems: Int = 500,
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .current
    ) {
        self.ignoreRules = ignoreRules
        self.timeWindowDays = timeWindowDays
        self.homeDirectory = homeDirectory
        self.maxItems = maxItems
        self.now = now
        self.calendar = calendar
    }

    package func update(sourceID: String, items: [ActivityItem]) {
        itemsBySource[sourceID] = items
        recompute()
    }

    /// Hides an item until a source reports activity newer than now (used when a file no longer exists).
    package func remove(path: String) {
        removedAt[path] = now()
        recompute()
    }

    /// Items for the current category and search text, inside the time window, at most `maxItems`.
    package var visibleItems: [ActivityItem] {
        let cutoff = now().addingTimeInterval(-Double(timeWindowDays) * 86_400)
        let matching = allItems.lazy.filter { item in
            if item.kind != .volume, let date = item.date, date < cutoff { return false }
            return self.category.includes(item) && Self.matchesSearch(item.displayName, self.searchText)
        }
        return Array(matching.prefix(maxItems))
    }

    package var sections: [TimelineSection] {
        let items = visibleItems
        var result: [TimelineSection] = []
        let undated = items.filter { $0.date == nil }
        if !undated.isEmpty { result.append(TimelineSection(kind: .connected, items: undated)) }
        let current = now()
        var grouped: [TimeGroup: [ActivityItem]] = [:]
        for item in items {
            guard let date = item.date else { continue }
            grouped[TimeGroup.group(for: date, now: current, calendar: calendar), default: []].append(item)
        }
        for group in TimeGroup.allCases {
            if let groupItems = grouped[group] { result.append(TimelineSection(kind: .time(group), items: groupItems)) }
        }
        return result
    }

    nonisolated package static func matchesSearch(_ name: String, _ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || name.localizedCaseInsensitiveContains(trimmed)
    }

    private func recompute() {
        var newest: [String: ActivityItem] = [:]
        for item in itemsBySource.values.joined() {
            if let removed = removedAt[item.id], (item.date ?? .distantPast) <= removed { continue }
            if ignoreRules.isIgnored(item, homeDirectory: homeDirectory) { continue }
            if let existing = newest[item.id], (existing.date ?? .distantPast) >= (item.date ?? .distantPast) {
                continue
            }
            newest[item.id] = item
        }
        allItems = newest.values.sorted { a, b in
            let da = a.date ?? .distantPast, db = b.date ?? .distantPast
            return da != db ? da > db : a.displayName.localizedStandardCompare(b.displayName) == .orderedAscending
        }
        onChange?()
    }
}
