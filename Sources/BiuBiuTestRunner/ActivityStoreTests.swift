import Foundation
import BiuBiuCore

@MainActor
enum ActivityStoreTests {
    static let now = Date(timeIntervalSince1970: 2_000_000_000)
    static let home = "/Users/me"

    static func makeStore(rules: IgnoreRules = IgnoreRules(rules: [], ignoreHidden: true),
                          days: Int = 7, maxItems: Int = 500, clock: @escaping () -> Date = { now }) -> ActivityStore {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return ActivityStore(ignoreRules: rules, timeWindowDays: days, homeDirectory: home,
                             maxItems: maxItems, now: clock, calendar: calendar)
    }

    static func file(_ path: String, _ minutesAgo: Double, _ event: ActivityEvent = .saved,
                     kind: ActivityKind = .file) -> ActivityItem {
        ActivityItem(url: URL(fileURLWithPath: path), kind: kind, event: event,
                     date: now.addingTimeInterval(-minutesAgo * 60))
    }

    static var tests: [TestCase] { [
        TestCase("Store: merges sources newest first") {
            let store = makeStore()
            store.update(sourceID: "a", items: [file("/Users/me/a.txt", 30), file("/Users/me/c.txt", 1)])
            store.update(sourceID: "b", items: [file("/Users/me/b.txt", 10)])
            expectEqual(store.allItems.map(\.displayName), ["c.txt", "b.txt", "a.txt"])
        },
        TestCase("Store: same path from two sources keeps the newest") {
            let store = makeStore()
            store.update(sourceID: "a", items: [file("/Users/me/a.txt", 30, .opened)])
            store.update(sourceID: "b", items: [file("/Users/me/a.txt", 5, .saved)])
            expectEqual(store.allItems.count, 1)
            expectEqual(store.allItems.first?.event, .saved)
        },
        TestCase("Store: a source update replaces that source's previous items") {
            let store = makeStore()
            store.update(sourceID: "a", items: [file("/Users/me/a.txt", 30)])
            store.update(sourceID: "a", items: [file("/Users/me/b.txt", 30)])
            expectEqual(store.allItems.map(\.displayName), ["b.txt"])
        },
        TestCase("Store: ignore rules filter and re-apply when changed") {
            let store = makeStore()
            store.update(sourceID: "a", items: [file("/Users/me/a.tmp", 1), file("/Users/me/b.txt", 2)])
            expectEqual(store.allItems.count, 2)
            store.ignoreRules = IgnoreRules(rules: [.fileExtension("tmp")], ignoreHidden: true)
            expectEqual(store.allItems.map(\.displayName), ["b.txt"])
        },
        TestCase("Store: caps what is shown, not what each category can reach") {
            let store = makeStore(maxItems: 3)
            store.update(sourceID: "a", items: (1...10).map { file("/Users/me/\($0).txt", Double($0)) }
                + [file("/Users/me/Downloads/old.zip", 100, .downloaded)])
            expectEqual(store.visibleItems.map(\.displayName), ["1.txt", "2.txt", "3.txt"])
            store.category = .downloads
            expectEqual(store.visibleItems.map(\.displayName), ["old.zip"])
        },
        TestCase("Store: search is case-insensitive and trims spaces") {
            let store = makeStore()
            store.update(sourceID: "a", items: [file("/Users/me/Report.PDF", 1), file("/Users/me/notes.md", 2)])
            store.searchText = "  report "
            expectEqual(store.visibleItems.map(\.displayName), ["Report.PDF"])
        },
        TestCase("Store: categories filter, and undated volumes only show under Disks") {
            let store = makeStore()
            let disk = ActivityItem(url: URL(fileURLWithPath: "/Volumes/T7"), kind: .volume, event: .mounted, date: nil)
            store.update(sourceID: "a", items: [file("/Users/me/a.txt", 1), file("/Users/me/Downloads/z.zip", 2, .downloaded)])
            store.update(sourceID: "v", items: [disk])
            expectEqual(store.visibleItems.count, 2)
            store.category = .downloads
            expectEqual(store.visibleItems.map(\.displayName), ["z.zip"])
            store.category = .volumes
            expectEqual(store.visibleItems.map(\.displayName), ["T7"])
            expectEqual(store.sections.first?.kind, .connected)
        },
        TestCase("Store: sections group by time in order") {
            let store = makeStore()
            store.update(sourceID: "a", items: [file("/Users/me/old.txt", 60 * 24 * 3), file("/Users/me/new.txt", 5)])
            expectEqual(store.sections.map(\.kind), [.time(.justNow), .time(.thisWeek)])
        },
        TestCase("Store: items older than the window disappear without a source update") {
            var current = now
            let store = makeStore(days: 1, clock: { current })
            store.update(sourceID: "a", items: [file("/Users/me/a.txt", 60)])
            expectEqual(store.visibleItems.count, 1)
            current = now.addingTimeInterval(86_400)
            expectEqual(store.visibleItems.count, 0)
        },
        TestCase("Store: removed path stays hidden until newer activity arrives") {
            var current = now
            let store = makeStore(clock: { current })
            store.update(sourceID: "a", items: [file("/Users/me/a.txt", 10)])
            store.remove(path: "/Users/me/a.txt")
            store.update(sourceID: "a", items: [file("/Users/me/a.txt", 10)])
            expectEqual(store.allItems.count, 0)
            current = now.addingTimeInterval(600)
            store.update(sourceID: "a", items: [file("/Users/me/a.txt", -5)])
            expectEqual(store.allItems.count, 1)
        },
        TestCase("Store: onChange fires for updates and filter changes") {
            let store = makeStore()
            var calls = 0
            store.onChange = { calls += 1 }
            store.update(sourceID: "a", items: [])
            store.searchText = "x"
            store.category = .files
            expectEqual(calls, 3)
        },
    ] }
}
