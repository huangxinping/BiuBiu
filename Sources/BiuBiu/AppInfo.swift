import Foundation

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
}
