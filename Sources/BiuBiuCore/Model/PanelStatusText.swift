import Foundation

/// What the panel's banner and empty-state label say, decided from state alone; the panel only localizes.
package enum PanelStatusText {
    package enum Banner: Equatable, Sendable {
        /// A short-lived notice such as "Path copied" or an error.
        case message(String)
        /// Protected folders macOS won't let BiuBiu read; the banner opens System Settings.
        case folderAccess([ProtectedFolder])
        /// Spotlight found nothing at all in the home folder, or the query could not start.
        case spotlightProblem
    }

    package enum EmptyState: Equatable, Sendable {
        case noMatches, loading, nothingYet
    }

    /// A transient message wins, then missing folder access, then a Spotlight problem.
    package static func banner(transient: String?, blockedFolders: [ProtectedFolder], spotlight: SpotlightStatus) -> Banner? {
        if let transient { return .message(transient) }
        if !blockedFolders.isEmpty { return .folderAccess(blockedFolders) }
        if spotlight == .noResults || spotlight == .failedToStart { return .spotlightProblem }
        return nil
    }

    /// nil while there are rows to show.
    package static func emptyState(rowCount: Int, searchText: String, spotlight: SpotlightStatus) -> EmptyState? {
        guard rowCount == 0 else { return nil }
        if !searchText.isEmpty { return .noMatches }
        return spotlight == .searching ? .loading : .nothingYet
    }
}
