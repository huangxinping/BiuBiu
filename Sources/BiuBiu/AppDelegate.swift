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
    private var settingsWindow: SettingsWindowController?
    private var welcomeWindow: WelcomeWindowController?
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
        // On first run, start reading folders only after the welcome window has explained the macOS
        // access prompts that reading them can trigger.
        if settings.hasSeenWelcome { startSources() } else { showWelcome() }
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
        panelController?.viewController.hotKeyDisplay = ok ? combo.localizedDisplayString : nil
        return ok
    }

    private func setIgnoreRules(_ rules: IgnoreRules) {
        settings.ignoreRules = rules
        store.ignoreRules = rules
        settingsWindow?.ignoreRulesViewController.update(rules: rules)
    }

    private func showSettings() {
        panelController?.hide()
        if settingsWindow == nil {
            let general = GeneralSettingsViewController(settings: settings, hotKeyWorking: hotKeyWorking, callbacks: .init(
                hotKeyChanged: { [weak self] combo in
                    guard let self else { return false }
                    self.settings.hotKey = combo
                    return self.applyHotKey()
                },
                hotKeyRecording: { [weak self] recording in
                    if recording { self?.hotKeys.unregister() } else { self?.applyHotKey() }
                },
                timeWindowChanged: { [weak self] days in
                    guard let self else { return }
                    self.settings.timeWindowDays = days
                    self.store.timeWindowDays = days
                    self.startSources()
                },
                hiddenCategoriesChanged: { [weak self] hidden in
                    guard let self else { return }
                    self.settings.hiddenCategories = hidden
                    self.panelController?.viewController.reloadCategories()
                }
            ))
            let ignore = IgnoreRulesViewController(rules: settings.ignoreRules) { [weak self] rules in
                self?.setIgnoreRules(rules)
            }
            settingsWindow = SettingsWindowController(general: general, ignoreRules: ignore)
        }
        settingsWindow?.present()
    }

    private func showWelcome() {
        settings.hasSeenWelcome = true
        // Set from docs/superpowers/notes/2026-10-01-privacy-probe.md (Task 1).
        welcomeWindow = WelcomeWindowController(shortcut: settings.hotKey?.localizedDisplayString,
                                                privacyNote: .expectPrompts) { [weak self] in
            self?.welcomeWindow = nil
            self?.startSources()
        }
        welcomeWindow?.present()
    }
}
