import Foundation

/// A producer of recent items. Each call to `onUpdate` delivers the source's complete current result set.
@MainActor
package protocol ActivitySource: AnyObject {
    var id: String { get }
    func start(since: Date, onUpdate: @escaping @MainActor ([ActivityItem]) -> Void)
    func stop()
}
