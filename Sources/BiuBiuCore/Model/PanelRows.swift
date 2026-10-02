import Foundation

package enum PanelRow: Hashable, Sendable {
    case pinnedHeader(collapsed: Bool)
    case sectionHeader(SectionKind)
    case pinned(PinnedEntry)
    case item(ActivityItem)

    package var isSelectable: Bool {
        switch self {
        case .pinned, .item: true
        case .pinnedHeader, .sectionHeader: false
        }
    }

    package var displayName: String? {
        switch self {
        case .pinned(let entry): entry.displayName
        case .item(let item): item.displayName
        case .pinnedHeader, .sectionHeader: nil
        }
    }

    /// Where the row points to, if it points anywhere.
    package var url: URL? {
        switch self {
        case .pinned(let entry): entry.url
        case .item(let item): item.url
        case .pinnedHeader, .sectionHeader: nil
        }
    }
}

package enum PanelRowsBuilder {
    package static func rows(
        pins: [PinnedEntry],
        showPinned: Bool,
        pinnedCollapsed: Bool,
        searchText: String,
        sections: [TimelineSection]
    ) -> [PanelRow] {
        var rows: [PanelRow] = []
        let matchingPins = pins.filter { ActivityStore.matchesSearch($0.displayName, searchText) }
        if showPinned, !matchingPins.isEmpty {
            rows.append(.pinnedHeader(collapsed: pinnedCollapsed))
            if !pinnedCollapsed { rows += matchingPins.map(PanelRow.pinned) }
        }
        for section in sections where !section.items.isEmpty {
            rows.append(.sectionHeader(section.kind))
            rows += section.items.map(PanelRow.item)
        }
        return rows
    }

    /// The next selectable row moving by `step` (+1 down, -1 up). With no selection, starts from the edge.
    package static func nextSelectable(in rows: [PanelRow], from current: Int?, step: Int) -> Int? {
        var index = current.map { $0 + step } ?? (step > 0 ? 0 : rows.count - 1)
        while rows.indices.contains(index) {
            if rows[index].isSelectable { return index }
            index += step
        }
        return current
    }

    /// Where `row` is after a reload: the same kind of row (pin or timeline item) for the same file, so a
    /// timeline selection does not jump to the pinned copy of the same file.
    package static func index(of row: PanelRow, in rows: [PanelRow]) -> Int? {
        guard let url = row.url else { return nil }
        return rows.firstIndex { candidate in
            switch (row, candidate) {
            case (.pinned, .pinned), (.item, .item): candidate.url == url
            default: false
            }
        }
    }

    package static func firstSelectable(in rows: [PanelRow]) -> Int? {
        rows.firstIndex(where: \.isSelectable)
    }
}
