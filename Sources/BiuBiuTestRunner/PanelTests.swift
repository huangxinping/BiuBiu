import CoreGraphics
import Foundation
import BiuBiuCore

@MainActor
enum PanelTests {
    static let item = ActivityItem(url: URL(fileURLWithPath: "/Users/me/a.txt"), kind: .file, event: .saved, date: Date())
    static let pin = PinnedEntry(pin: Pin(bookmark: Data(), path: "/Users/me/Proj", pinnedAt: Date()),
                                 url: URL(fileURLWithPath: "/Users/me/Proj"))

    static var tests: [TestCase] { [
        TestCase("PanelRows: pinned block then sections") {
            let rows = PanelRowsBuilder.rows(pins: [pin], showPinned: true, pinnedCollapsed: false, searchText: "",
                                             sections: [TimelineSection(kind: .time(.justNow), items: [item])])
            expectEqual(rows, [.pinnedHeader(collapsed: false), .pinned(pin), .sectionHeader(.time(.justNow)), .item(item)])
        },
        TestCase("PanelRows: collapsed, hidden, and search-filtered pins") {
            let sections = [TimelineSection(kind: .time(.today), items: [item])]
            let collapsed = PanelRowsBuilder.rows(pins: [pin], showPinned: true, pinnedCollapsed: true, searchText: "", sections: sections)
            expectEqual(collapsed.first, .pinnedHeader(collapsed: true))
            expectEqual(collapsed.count, 3)
            let hidden = PanelRowsBuilder.rows(pins: [pin], showPinned: false, pinnedCollapsed: false, searchText: "", sections: sections)
            expectEqual(hidden.first, .sectionHeader(.time(.today)))
            let searched = PanelRowsBuilder.rows(pins: [pin], showPinned: true, pinnedCollapsed: false, searchText: "zzz", sections: [])
            expect(searched.isEmpty)
        },
        TestCase("PanelRows: keyboard selection skips headers and stops at the edges") {
            let rows: [PanelRow] = [.pinnedHeader(collapsed: false), .pinned(pin), .sectionHeader(.time(.today)), .item(item)]
            expectEqual(PanelRowsBuilder.firstSelectable(in: rows), 1)
            expectEqual(PanelRowsBuilder.nextSelectable(in: rows, from: 1, step: 1), 3)
            expectEqual(PanelRowsBuilder.nextSelectable(in: rows, from: 3, step: 1), 3)
            expectEqual(PanelRowsBuilder.nextSelectable(in: rows, from: 3, step: -1), 1)
            expectEqual(PanelRowsBuilder.nextSelectable(in: rows, from: 1, step: -1), 1)
            expectEqual(PanelRowsBuilder.nextSelectable(in: rows, from: nil, step: 1), 1)
            expect(PanelRowsBuilder.nextSelectable(in: [.sectionHeader(.connected)], from: nil, step: 1) == nil)
        },
        TestCase("KeyMap: navigation, open, reveal, escape") {
            expectEqual(PanelKeyMap.command(keyCode: 125, modifiers: [], searchIsEmpty: false), .moveDown)
            expectEqual(PanelKeyMap.command(keyCode: 126, modifiers: [], searchIsEmpty: false), .moveUp)
            expectEqual(PanelKeyMap.command(keyCode: 36, modifiers: [], searchIsEmpty: false), .open)
            expectEqual(PanelKeyMap.command(keyCode: 76, modifiers: [.command], searchIsEmpty: false), .reveal)
            expectEqual(PanelKeyMap.command(keyCode: 53, modifiers: [], searchIsEmpty: false), .escape)
        },
        TestCase("KeyMap: space previews only with an empty search; ⌘Y always previews") {
            expectEqual(PanelKeyMap.command(keyCode: 49, modifiers: [], searchIsEmpty: true), .quickLook)
            expect(PanelKeyMap.command(keyCode: 49, modifiers: [], searchIsEmpty: false) == nil)
            expect(PanelKeyMap.command(keyCode: 49, modifiers: [.shift], searchIsEmpty: true) == nil)
            expectEqual(PanelKeyMap.command(keyCode: 16, modifiers: [.command], searchIsEmpty: false), .quickLook)
        },
        TestCase("KeyMap: ⌘1-⌘6 pick categories; plain letters and digits type") {
            expectEqual(PanelKeyMap.command(keyCode: 18, modifiers: [.command], searchIsEmpty: true), .selectCategory(0))
            expectEqual(PanelKeyMap.command(keyCode: 22, modifiers: [.command], searchIsEmpty: true), .selectCategory(5))
            expect(PanelKeyMap.command(keyCode: 18, modifiers: [], searchIsEmpty: true) == nil)
            expect(PanelKeyMap.command(keyCode: 35, modifiers: [], searchIsEmpty: true) == nil)
            expectEqual(PanelKeyMap.command(keyCode: 35, modifiers: [.command], searchIsEmpty: true), .togglePin)
            expectEqual(PanelKeyMap.command(keyCode: 8, modifiers: [.command, .option], searchIsEmpty: true), .copyPath)
            expect(PanelKeyMap.command(keyCode: 8, modifiers: [.command], searchIsEmpty: true) == nil)
        },
        TestCase("Toggle: a reopen right after the panel hid is the same click and is ignored") {
            // Clicking the status item while the panel is open closes it on mouse-down (outside-click
            // monitor), then the item's mouse-up action asks to toggle about 20–50 ms later.
            var debouncer = PanelToggleDebouncer()
            let hid = Date(timeIntervalSince1970: 1_000)
            debouncer.panelDidHide(at: hid)
            expect(!debouncer.shouldReopen(at: hid.addingTimeInterval(0.044)))
            expect(!debouncer.shouldReopen(at: hid.addingTimeInterval(0.3)))
        },
        TestCase("Toggle: reopening is allowed when nothing hid the panel just before") {
            var debouncer = PanelToggleDebouncer()
            let now = Date(timeIntervalSince1970: 1_000)
            expect(debouncer.shouldReopen(at: now))
            debouncer.panelDidHide(at: now)
            expect(debouncer.shouldReopen(at: now.addingTimeInterval(0.5)))
        },
        TestCase("Placement: hangs below the anchor, clamped inside the screen") {
            let visible = CGRect(x: 0, y: 0, width: 1440, height: 875)
            let size = CGSize(width: 360, height: 520)
            let mid = PanelPlacement.origin(panelSize: size, anchor: CGRect(x: 700, y: 876, width: 24, height: 24), visibleFrame: visible)
            expectEqual(mid, CGPoint(x: 532, y: 352))
            let edge = PanelPlacement.origin(panelSize: size, anchor: CGRect(x: 1420, y: 876, width: 24, height: 24), visibleFrame: visible)
            expectEqual(edge.x, 1440 - 8 - 360)
        },
        TestCase("Placement: top center without an anchor, never below the screen") {
            let visible = CGRect(x: 1440, y: 0, width: 1920, height: 400)
            let origin = PanelPlacement.origin(panelSize: CGSize(width: 360, height: 520), anchor: nil, visibleFrame: visible)
            expectEqual(origin, CGPoint(x: 1440 + 960 - 180, y: 8))
        },
    ] }
}
