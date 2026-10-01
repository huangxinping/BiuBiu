import AppKit

@MainActor
enum ItemActions {
    /// Returns false when the item is gone.
    static func open(_ url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        return NSWorkspace.shared.open(url)
    }

    static func open(_ url: URL, withApplicationAt app: URL) {
        NSWorkspace.shared.open([url], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
    }

    static func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    static func copyPath(_ url: URL) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url.path, forType: .string)
    }

    /// Apps that can open the file, the default one first.
    static func applications(toOpen url: URL) -> [URL] {
        let all = NSWorkspace.shared.urlsForApplications(toOpen: url)
        guard let preferred = NSWorkspace.shared.urlForApplication(toOpen: url) else { return all }
        return [preferred] + all.filter { $0 != preferred }
    }

    static func icon(for url: URL?) -> NSImage? {
        guard let url else { return NSImage(systemSymbolName: "questionmark.square.dashed", accessibilityDescription: nil) }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}
