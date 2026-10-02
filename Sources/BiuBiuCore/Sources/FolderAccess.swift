import Foundation

/// The home folders macOS keeps behind a per-app access prompt.
package enum ProtectedFolder: String, CaseIterable, Sendable {
    case desktop = "Desktop"
    case documents = "Documents"
    case downloads = "Downloads"

    package func path(home: String) -> String { home + "/" + rawValue }
}

/// Which protected folders BiuBiu can read.
///
/// A Spotlight query over the whole home folder never makes macOS ask for access to these folders: it
/// silently leaves their files out. Reading a folder is what makes macOS ask, so the app reads each one
/// before starting the file query, off the main thread, since the read waits for the user's answer.
package enum FolderAccess {
    package static func readableFolders(
        home: String,
        canRead: (String) -> Bool = { (try? FileManager.default.contentsOfDirectory(atPath: $0)) != nil }
    ) -> Set<ProtectedFolder> {
        Set(ProtectedFolder.allCases.filter { canRead($0.path(home: home)) })
    }

    package static func blocked(readable: Set<ProtectedFolder>) -> [ProtectedFolder] {
        ProtectedFolder.allCases.filter { !readable.contains($0) }
    }

    /// A running file query doesn't pick up a folder that became readable after it started.
    package static func needsRestart(before: Set<ProtectedFolder>, after: Set<ProtectedFolder>) -> Bool {
        !after.subtracting(before).isEmpty
    }
}
