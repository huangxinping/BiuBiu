import Foundation

/// Apps recently opened, installed or updated, from the Spotlight index of the Applications folders.
@MainActor
package final class AppSource: ActivitySource {
    package let id = "spotlight.apps"
    private let runner = MetadataQueryRunner()
    private let scopes: [URL]

    package static let defaultScopes = [
        URL(fileURLWithPath: "/Applications", isDirectory: true),
        URL(fileURLWithPath: NSHomeDirectory() + "/Applications", isDirectory: true),
        URL(fileURLWithPath: "/System/Applications", isDirectory: true),
    ]

    package init(scopes: [URL] = AppSource.defaultScopes) {
        self.scopes = scopes
    }

    package func start(since: Date, onUpdate: @escaping @MainActor ([ActivityItem]) -> Void) {
        let predicate = NSPredicate(
            format: "(%K == 'com.apple.application-bundle') AND ((%K >= %@) OR (%K >= %@))",
            NSMetadataItemContentTypeKey,
            NSMetadataItemDateAddedKey, since as NSDate,
            NSMetadataItemLastUsedDateKey, since as NSDate
        )
        runner.start(
            predicate: predicate,
            scopes: scopes.filter { FileManager.default.fileExists(atPath: $0.path) },
            attributes: [NSMetadataItemDateAddedKey, NSMetadataItemLastUsedDateKey],
            onResults: { records in
                let now = Date()
                onUpdate(records.compactMap { record in
                    Self.item(path: record.path, dateAdded: record.date(NSMetadataItemDateAddedKey),
                              lastUsed: record.date(NSMetadataItemLastUsedDateKey), since: since, now: now)
                })
            },
            onStatus: { _ in }
        )
    }

    package func stop() { runner.stop() }

    /// The newer of "added to the folder" (installed or updated) and "last opened" decides the event;
    /// a tie goes to installed. Dates after `now` are bad data, as in ActivityClassifier.
    package static func item(path: String, dateAdded: Date?, lastUsed: Date?, since: Date, now: Date) -> ActivityItem? {
        let latestPlausible = now.addingTimeInterval(ActivityClassifier.tieTolerance)
        var candidates: [(ActivityEvent, Date)] = []
        if let added = dateAdded, added <= latestPlausible { candidates.append((.installed, added)) }
        if let used = lastUsed, used <= latestPlausible { candidates.append((.opened, used)) }
        guard let newest = candidates.map(\.1).max(), newest >= since else { return nil }
        let event = candidates.first { newest.timeIntervalSince($0.1) <= ActivityClassifier.tieTolerance }!.0
        let url = URL(fileURLWithPath: path)
        return ActivityItem(url: url, kind: .application, event: event, date: newest,
                            displayName: url.deletingPathExtension().lastPathComponent)
    }
}
