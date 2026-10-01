import Foundation
import BiuBiuCore

/// `BiuBiu --dump` prints what the sources currently see, for checking Spotlight without the UI.
@MainActor
enum DumpMode {
    static func run() -> Never {
        let settings = AppSettings(defaults: .standard)
        let store = ActivityStore(ignoreRules: settings.ignoreRules, timeWindowDays: settings.timeWindowDays,
                                  homeDirectory: NSHomeDirectory())
        let fileSource = SpotlightFileSource()
        var status = SpotlightStatus.searching
        fileSource.onStatus = { status = $0 }
        let since = Date().addingTimeInterval(-Double(settings.timeWindowDays) * 86_400)
        let sources: [ActivitySource] = [fileSource, AppInstallSource(), VolumeSource()]
        for source in sources {
            source.start(since: since) { store.update(sourceID: source.id, items: $0) }
        }
        let deadline = Date().addingTimeInterval(30)
        while status == .searching, Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        }
        RunLoop.main.run(until: Date().addingTimeInterval(1))

        let dateFormatter = ISO8601DateFormatter()
        print("Spotlight status: \(status)")
        for item in store.allItems.prefix(40) {
            let date = item.date.map(dateFormatter.string(from:)) ?? "-------------------"
            print("\(date)  \(item.event.rawValue.padding(toLength: 10, withPad: " ", startingAt: 0))  \(item.url.path)")
        }
        print("Total: \(store.allItems.count)")
        exit(0)
    }
}
