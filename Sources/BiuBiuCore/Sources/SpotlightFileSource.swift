import Foundation

/// Recent files and folders under the home folder, from the Spotlight index.
@MainActor
package final class SpotlightFileSource: ActivitySource {
    package let id = "spotlight.files"
    package var onStatus: ((SpotlightStatus) -> Void)?
    private let runner = MetadataQueryRunner()
    private let downloadsPath: String
    private let userApplicationsPath: String

    package init(homeDirectory: String = NSHomeDirectory()) {
        downloadsPath = homeDirectory + "/Downloads"
        userApplicationsPath = homeDirectory + "/Applications/"
    }

    package func start(since: Date, onUpdate: @escaping @MainActor ([ActivityItem]) -> Void) {
        let predicate = NSPredicate(
            format: "(%K >= %@) OR (%K >= %@) OR (%K >= %@)",
            NSMetadataItemLastUsedDateKey, since as NSDate,
            NSMetadataItemContentModificationDateKey, since as NSDate,
            NSMetadataItemDateAddedKey, since as NSDate
        )
        let downloadsPath = downloadsPath
        let userApplicationsPath = userApplicationsPath
        runner.start(
            predicate: predicate,
            scopes: [NSMetadataQueryUserHomeScope],
            onResults: { results in
                onUpdate(results.compactMap { result in
                    if Self.isLeftToAppSource(contentType: result.string(NSMetadataItemContentTypeKey),
                                              path: result.string(NSMetadataItemPathKey),
                                              userApplicationsPath: userApplicationsPath) {
                        return nil
                    }
                    return Self.item(from: result, since: since, downloadsPath: downloadsPath)
                })
            },
            onStatus: { [weak self] status in self?.onStatus?(status) }
        )
    }

    package func stop() { runner.stop() }

    /// Apps in ~/Applications are AppInstallSource's job; skipping them here makes them show up as apps,
    /// not as "Added" files. Apps elsewhere (say, just unzipped in Downloads) stay files.
    package static func isLeftToAppSource(contentType: String?, path: String?, userApplicationsPath: String) -> Bool {
        contentType == "com.apple.application-bundle" && path?.hasPrefix(userApplicationsPath) == true
    }

    private static func item(from result: NSMetadataItem, since: Date, downloadsPath: String) -> ActivityItem? {
        guard let path = result.string(NSMetadataItemPathKey) else { return nil }
        let metadata = FileMetadata(
            path: path,
            isFolder: result.string(NSMetadataItemContentTypeKey) == "public.folder",
            lastUsed: result.date(NSMetadataItemLastUsedDateKey),
            contentModified: result.date(NSMetadataItemContentModificationDateKey),
            dateAdded: result.date(NSMetadataItemDateAddedKey),
            whereFroms: result.strings(NSMetadataItemWhereFromsKey)
        )
        return ActivityClassifier.classify(metadata, since: since, downloadsPath: downloadsPath)
    }
}
