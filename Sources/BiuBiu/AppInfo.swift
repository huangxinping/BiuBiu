import AppKit

enum AppInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    /// Written into Info.plist by scripts/build-app.sh from `git remote get-url origin`; nil in dev builds.
    static var repositoryURL: URL? {
        guard let string = Bundle.main.object(forInfoDictionaryKey: "BiuBiuRepositoryURL") as? String,
              string.hasPrefix("https://") else { return nil }
        return URL(string: string)
    }

    static var releasesURL: URL? { repositoryURL?.appendingPathComponent("releases/latest") }

    /// System Settings › Privacy & Security › Files & Folders.
    static func openFolderAccessSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders")
        else { return }
        NSWorkspace.shared.open(url)
    }
}
