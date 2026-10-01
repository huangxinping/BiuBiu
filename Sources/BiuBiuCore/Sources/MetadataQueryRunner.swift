import Foundation

package enum SpotlightStatus: Equatable, Sendable {
    case searching
    case ok
    /// The query finished gathering with nothing at all, which usually means the folder is not indexed.
    case noResults
    case failedToStart
}

/// Runs one live NSMetadataQuery and hands every result snapshot to `onResults`.
@MainActor
final class MetadataQueryRunner {
    private var query: NSMetadataQuery?
    private var observers: [NSObjectProtocol] = []

    func start(
        predicate: NSPredicate,
        scopes: [Any],
        onResults: @escaping @MainActor ([NSMetadataItem]) -> Void,
        onStatus: @escaping @MainActor (SpotlightStatus) -> Void
    ) {
        stop()
        let query = NSMetadataQuery()
        query.predicate = predicate
        query.searchScopes = scopes
        query.notificationBatchingInterval = 0.5
        self.query = query

        let center = NotificationCenter.default
        let publish: @MainActor (Bool) -> Void = { [weak self, weak query] finishedGathering in
            guard let self, let query, self.query === query else { return }
            query.disableUpdates()
            let items = (0..<query.resultCount).compactMap { query.result(at: $0) as? NSMetadataItem }
            query.enableUpdates()
            onResults(items)
            if finishedGathering { onStatus(items.isEmpty ? .noResults : .ok) }
        }
        observers = [
            center.addObserver(forName: .NSMetadataQueryDidFinishGathering, object: query, queue: .main) { _ in
                MainActor.assumeIsolated { publish(true) }
            },
            center.addObserver(forName: .NSMetadataQueryDidUpdate, object: query, queue: .main) { _ in
                MainActor.assumeIsolated { publish(false) }
            },
        ]
        onStatus(.searching)
        if !query.start() {
            Log.sources.error("NSMetadataQuery failed to start: \(predicate.predicateFormat, privacy: .public)")
            onStatus(.failedToStart)
        }
    }

    func stop() {
        query?.stop()
        query = nil
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
    }
}

extension NSMetadataItem {
    func date(_ key: String) -> Date? { value(forAttribute: key) as? Date }
    func string(_ key: String) -> String? { value(forAttribute: key) as? String }
    func strings(_ key: String) -> [String] { value(forAttribute: key) as? [String] ?? [] }
}
