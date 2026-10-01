import Foundation

package enum IgnoreRule: Codable, Hashable, Sendable {
    /// Matches the path itself and everything below it. May start with "~/".
    case pathPrefix(String)
    /// Matches when the path contains this fragment. Folders are matched with a trailing "/".
    case pathContains(String)
    /// Matches files (not folders) with this extension, case-insensitive, without the dot.
    case fileExtension(String)

    package var value: String {
        switch self {
        case .pathPrefix(let v), .pathContains(let v), .fileExtension(let v): v
        }
    }

    package func withValue(_ newValue: String) -> IgnoreRule {
        switch self {
        case .pathPrefix: .pathPrefix(newValue)
        case .pathContains: .pathContains(newValue)
        case .fileExtension: .fileExtension(newValue)
        }
    }

    /// Replaces the home directory prefix with "~" so rules stay readable and portable.
    package static func abbreviate(_ path: String, homeDirectory: String) -> String {
        let home = homeDirectory.hasSuffix("/") ? String(homeDirectory.dropLast()) : homeDirectory
        if path == home { return "~" }
        if path.hasPrefix(home + "/") { return "~" + path.dropFirst(home.count) }
        return path
    }

    package static func expand(_ path: String, homeDirectory: String) -> String {
        let home = homeDirectory.hasSuffix("/") ? String(homeDirectory.dropLast()) : homeDirectory
        if path == "~" { return home }
        if path.hasPrefix("~/") { return home + path.dropFirst(1) }
        return path
    }

    func matches(path: String, isDirectory: Bool, homeDirectory: String) -> Bool {
        switch self {
        case .pathPrefix(let raw):
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return false }
            var prefix = Self.expand(trimmed, homeDirectory: homeDirectory)
            if !prefix.hasSuffix("/") { prefix += "/" }
            return (path + "/").hasPrefix(prefix)
        case .pathContains(let fragment):
            guard !fragment.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
            let candidate = isDirectory ? path + "/" : path
            return candidate.contains(fragment)
        case .fileExtension(let raw):
            guard !isDirectory else { return false }
            let ext = raw.trimmingCharacters(in: CharacterSet(charactersIn: ". ")).lowercased()
            guard !ext.isEmpty else { return false }
            return (path as NSString).pathExtension.lowercased() == ext
        }
    }
}

package struct IgnoreRules: Codable, Hashable, Sendable {
    package var rules: [IgnoreRule]
    package var ignoreHidden: Bool

    package init(rules: [IgnoreRule], ignoreHidden: Bool) {
        self.rules = rules
        self.ignoreHidden = ignoreHidden
    }

    package static let defaults = IgnoreRules(
        rules: [
            .pathPrefix("~/Library/"),
            .pathPrefix("~/.Trash/"),
            .pathContains(".app/"),
            .pathContains("/node_modules/"),
            .pathContains("/.git/"),
            .pathContains("/DerivedData/"),
            .pathContains("/__pycache__/"),
            .pathContains(".photoslibrary"),
            .pathContains(".musiclibrary"),
            .pathContains(".tvlibrary"),
            .fileExtension("tmp"),
            .fileExtension("part"),
            .fileExtension("crdownload"),
            .fileExtension("download"),
            .fileExtension("swp"),
        ],
        ignoreHidden: true
    )

    package func isIgnored(path: String, isDirectory: Bool, homeDirectory: String) -> Bool {
        if ignoreHidden, path.split(separator: "/").contains(where: { $0.hasPrefix(".") || $0 == "Icon\r" }) {
            return true
        }
        return rules.contains { $0.matches(path: path, isDirectory: isDirectory, homeDirectory: homeDirectory) }
    }

    package func isIgnored(_ item: ActivityItem, homeDirectory: String) -> Bool {
        let isDirectory = item.kind == .folder || item.kind == .volume
        return isIgnored(path: item.url.path, isDirectory: isDirectory, homeDirectory: homeDirectory)
    }
}
