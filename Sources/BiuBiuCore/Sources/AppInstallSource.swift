import Foundation

/// Apps recently added to /Applications or ~/Applications.
@MainActor
package final class AppInstallSource: ActivitySource {
    package let id = "spotlight.apps"
    private let runner = MetadataQueryRunner()
    private let scopes: [URL]

    package init(scopes: [URL] = [
        URL(fileURLWithPath: "/Applications", isDirectory: true),
        URL(fileURLWithPath: NSHomeDirectory() + "/Applications", isDirectory: true),
    ]) {
        self.scopes = scopes
    }

    package func start(since: Date, onUpdate: @escaping @MainActor ([ActivityItem]) -> Void) {
        let predicate = NSPredicate(
            format: "(%K == 'com.apple.application-bundle') AND (%K >= %@)",
            NSMetadataItemContentTypeKey, NSMetadataItemDateAddedKey, since as NSDate
        )
        runner.start(
            predicate: predicate,
            scopes: scopes.filter { FileManager.default.fileExists(atPath: $0.path) },
            attributes: [NSMetadataItemDateAddedKey],
            onResults: { records in
                onUpdate(records.compactMap { record in
                    guard let added = record.date(NSMetadataItemDateAddedKey) else { return nil }
                    let url = URL(fileURLWithPath: record.path)
                    return ActivityItem(url: url, kind: .application, event: .installed, date: added,
                                        displayName: url.deletingPathExtension().lastPathComponent)
                })
            },
            onStatus: { _ in }
        )
    }

    package func stop() { runner.stop() }
}
