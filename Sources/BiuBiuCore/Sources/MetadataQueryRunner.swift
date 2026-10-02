import Foundation

package enum SpotlightStatus: Equatable, Sendable {
    case searching
    case ok
    /// The query finished gathering with nothing at all, which usually means the folder is not indexed.
    case noResults
    case failedToStart

    /// The status after a result snapshot. "No results" is decided when gathering ends, and cleared as soon
    /// as a later update brings anything.
    package static func next(current: SpotlightStatus, recordCount: Int, finishedGathering: Bool) -> SpotlightStatus {
        if finishedGathering { return recordCount == 0 ? .noResults : .ok }
        return recordCount > 0 ? .ok : current
    }
}

/// One Spotlight result: its path and the attributes the query was told to collect.
package struct MetadataRecord {
    package let path: String
    private let values: [String: Any]
    private let item: NSMetadataItem?

    package init(path: String, values: [String: Any], item: NSMetadataItem? = nil) {
        self.path = path
        self.values = values
        self.item = item
    }

    /// Reads an attribute the query cannot cache (file-system dates, like the path). Each call is a round
    /// trip to the Spotlight server, so use it only for the few records that need it.
    package func uncachedDate(_ key: String) -> Date? { item?.value(forAttribute: key) as? Date }

    package func date(_ key: String) -> Date? { values[key] as? Date }
    package func string(_ key: String) -> String? { values[key] as? String }
    package func strings(_ key: String) -> [String] { values[key] as? [String] ?? [] }
}

/// Runs one live NSMetadataQuery and hands every result snapshot to `onResults`.
///
/// Attributes come from the query's own cache (`valueListAttributes` + `value(ofAttribute:forResultAt:)`).
/// Asking each `NSMetadataItem` instead costs a synchronous round trip to the Spotlight server per
/// attribute: about 35 s for 23k results, which froze the main thread. The path is not in that cache,
/// but reading it from the item is cheap.
@MainActor
package final class MetadataQueryRunner {
    private var query: NSMetadataQuery?
    private var observers: [NSObjectProtocol] = []
    private var status = SpotlightStatus.searching

    package init() {}

    package func start(
        predicate: NSPredicate,
        scopes: [Any],
        attributes: [String],
        onResults: @escaping @MainActor ([MetadataRecord]) -> Void,
        onStatus: @escaping @MainActor (SpotlightStatus) -> Void
    ) {
        stop()
        let query = NSMetadataQuery()
        query.predicate = predicate
        query.searchScopes = scopes
        query.valueListAttributes = attributes
        query.notificationBatchingInterval = 0.5
        self.query = query

        let center = NotificationCenter.default
        let publish: @MainActor (Bool) -> Void = { [weak self, weak query] finishedGathering in
            guard let self, let query, self.query === query else { return }
            query.disableUpdates()
            let records = (0..<query.resultCount).compactMap { index -> MetadataRecord? in
                guard let item = query.result(at: index) as? NSMetadataItem,
                      let path = item.value(forAttribute: NSMetadataItemPathKey) as? String else { return nil }
                var values: [String: Any] = [:]
                for key in attributes {
                    if let value = query.value(ofAttribute: key, forResultAt: index) { values[key] = value }
                }
                return MetadataRecord(path: path, values: values, item: item)
            }
            query.enableUpdates()
            onResults(records)
            let next = SpotlightStatus.next(current: self.status, recordCount: records.count,
                                            finishedGathering: finishedGathering)
            if next != self.status {
                self.status = next
                onStatus(next)
            }
        }
        observers = [
            center.addObserver(forName: .NSMetadataQueryDidFinishGathering, object: query, queue: .main) { _ in
                MainActor.assumeIsolated { publish(true) }
            },
            center.addObserver(forName: .NSMetadataQueryDidUpdate, object: query, queue: .main) { _ in
                MainActor.assumeIsolated { publish(false) }
            },
        ]
        status = .searching
        onStatus(.searching)
        if !query.start() {
            Log.sources.error("NSMetadataQuery failed to start: \(predicate.predicateFormat, privacy: .public)")
            status = .failedToStart
            onStatus(.failedToStart)
        }
    }

    package func stop() {
        query?.stop()
        query = nil
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
    }
}
