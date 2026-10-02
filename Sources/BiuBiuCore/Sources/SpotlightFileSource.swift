import Foundation

/// Recent files and folders under the home folder, from the Spotlight index.
@MainActor
package final class SpotlightFileSource: ActivitySource {
    package let id = "spotlight.files"
    package var onStatus: ((SpotlightStatus) -> Void)?
    private let runner = MetadataQueryRunner()
    private let downloadsPath: String
    private let userApplicationsPath: String

    /// Everything `item(from:since:downloadsPath:)` and the app check read, collected by the query.
    private static let attributes = [
        NSMetadataItemContentTypeKey, NSMetadataItemLastUsedDateKey,
        NSMetadataItemContentModificationDateKey, NSMetadataItemDateAddedKey, NSMetadataItemWhereFromsKey,
    ]

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
            attributes: Self.attributes,
            onResults: { records in
                onUpdate(records.compactMap { record in
                    if Self.isLeftToAppSource(contentType: record.string(NSMetadataItemContentTypeKey),
                                              path: record.path,
                                              userApplicationsPath: userApplicationsPath) {
                        return nil
                    }
                    return Self.item(from: record, since: since, downloadsPath: downloadsPath)
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

    private static func item(from record: MetadataRecord, since: Date, downloadsPath: String) -> ActivityItem? {
        let whereFroms = record.strings(NSMetadataItemWhereFromsKey)
        // Only a download saved outside Downloads needs its creation date (see ActivityClassifier).
        let needsCreation = !whereFroms.isEmpty && !record.path.hasPrefix(downloadsPath + "/")
        let metadata = FileMetadata(
            path: record.path,
            isFolder: record.string(NSMetadataItemContentTypeKey) == "public.folder",
            lastUsed: record.date(NSMetadataItemLastUsedDateKey),
            // The file system's creation date: kMDItemContentCreationDate can come from EXIF or PDF metadata.
            contentCreated: needsCreation ? record.uncachedDate(NSMetadataItemFSCreationDateKey) : nil,
            contentModified: record.date(NSMetadataItemContentModificationDateKey),
            dateAdded: record.date(NSMetadataItemDateAddedKey),
            whereFroms: whereFroms
        )
        return ActivityClassifier.classify(metadata, since: since, downloadsPath: downloadsPath)
    }
}
