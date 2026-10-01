import AppKit
import BiuBiuCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings(defaults: .standard)
    private let pinStore = PinStore(fileURL: PinStore.defaultFileURL())
    private let fileSource = SpotlightFileSource()
    private let appSource = AppInstallSource()
    private let volumeSource = VolumeSource()
    private let hotKeys = HotKeyCenter()
    private lazy var store = ActivityStore(ignoreRules: settings.ignoreRules,
                                           timeWindowDays: settings.timeWindowDays,
                                           homeDirectory: NSHomeDirectory())
    private var statusItem: StatusItemController?
    private var panelController: PanelController?
    private var sourcesStartedAt = Date.distantPast
    private var hotKeyWorking = true

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.category = settings.lastCategory
        let panelViewController = PanelViewController(dependencies: .init(
            store: store,
            pinStore: pinStore,
            settings: settings,
            volumeSource: volumeSource,
            openSettings: { [weak self] in self?.showSettings() },
            close: { [weak self] in self?.panelController?.hide() },
            updateIgnoreRules: { [weak self] rules in self?.setIgnoreRules(rules) }
        ))
        let panel = PanelController(viewController: panelViewController)
        panel.onWillShow = { [weak self] in self?.restartSourcesIfStale() }
        panelController = panel

        statusItem = StatusItemController(
            onToggle: { [weak self] in self?.togglePanel(fromStatusItem: true) },
            onSettings: { [weak self] in self?.showSettings() },
            onQuit: { NSApp.terminate(nil) }
        )
        fileSource.onStatus = { [weak panelViewController] status in panelViewController?.spotlightStatus = status }
        store.onChange = { [weak panelViewController] in panelViewController?.storeDidChange() }

        applyHotKey()
        startSources()
    }

    // MARK: - Panel

    private func togglePanel(fromStatusItem: Bool) {
        guard let panelController, let statusItem else { return }
        let anchor = fromStatusItem
            ? statusItem.buttonScreenFrame
            : statusItem.visibleAnchor(onScreenContaining: NSEvent.mouseLocation)
        panelController.toggle(anchor: anchor)
    }

    // MARK: - Sources

    private func startSources() {
        let since = Date().addingTimeInterval(-Double(settings.timeWindowDays) * 86_400)
        let sources: [ActivitySource] = [fileSource, appSource, volumeSource]
        for source in sources {
            source.start(since: since) { [weak self] items in
                self?.store.update(sourceID: source.id, items: items)
            }
        }
        sourcesStartedAt = Date()
    }

    /// Spotlight queries keep their start date, so restart them once an hour to move the window forward.
    private func restartSourcesIfStale() {
        if Date().timeIntervalSince(sourcesStartedAt) > 3600 { startSources() }
    }

    // MARK: - Settings changes

    @discardableResult
    private func applyHotKey() -> Bool {
        hotKeys.unregister()
        guard let combo = settings.hotKey else {
            hotKeyWorking = true
            panelController?.viewController.hotKeyDisplay = nil
            return true
        }
        let ok = hotKeys.register(combo) { [weak self] in self?.togglePanel(fromStatusItem: false) }
        if !ok { Log.app.error("Could not register shortcut \(combo.displayString, privacy: .public)") }
        hotKeyWorking = ok
        panelController?.viewController.hotKeyDisplay = ok ? combo.displayString : nil
        return ok
    }

    private func setIgnoreRules(_ rules: IgnoreRules) {
        settings.ignoreRules = rules
        store.ignoreRules = rules
    }

    private func showSettings() {
        // Replaced by the settings window in Task 13.
        panelController?.hide()
    }
}
