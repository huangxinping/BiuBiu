import AppKit
import BiuBiuCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings(defaults: .standard)
    private let pinStore = PinStore(fileURL: PinStore.defaultFileURL())
    private let fileSource = SpotlightFileSource()
    private let appSource = AppSource()
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
    private var readableFolders: Set<ProtectedFolder> = []
    /// Waiting for the folder check in flight; nil when none is running.
    private var folderAccessWaiters: [@MainActor (_ gainedAccess: Bool) -> Void]?

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
        panel.onWillShow = { [weak self] in
            self?.restartSourcesIfStale()
            self?.recheckBlockedFolders()
        }
        panelController = panel

        statusItem = StatusItemController(
            onToggle: { [weak self] in self?.togglePanel(fromStatusItem: true) },
            onSettings: { [weak self] in self?.showSettings() },
            onQuit: { NSApp.terminate(nil) }
        )
        fileSource.onStatus = { [weak panelViewController] status in panelViewController?.spotlightStatus = status }
        store.onChange = { [weak panelViewController] in panelViewController?.storeDidChange() }

        applyHotKey(retryIfTaken: true)
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
        sourcesStartedAt = Date()
        start(appSource)
        start(volumeSource)
        // Reading the protected folders is what makes macOS ask for access; the home-wide file query
        // never asks and just leaves them out. So the file query starts once those questions are answered.
        checkFolderAccess { [weak self] _ in
            guard let self else { return }
            self.start(self.fileSource)
        }
    }

    private func start(_ source: ActivitySource) {
        let since = Date().addingTimeInterval(-Double(settings.timeWindowDays) * 86_400)
        source.start(since: since) { [weak self] items in
            self?.store.update(sourceID: source.id, items: items)
        }
    }

    /// Reads the protected folders off the main thread (the read waits while macOS asks the user),
    /// then reports whether a folder became readable since the last check.
    private func checkFolderAccess(then: @escaping @MainActor (_ gainedAccess: Bool) -> Void) {
        if folderAccessWaiters != nil {
            folderAccessWaiters?.append(then)
            return
        }
        folderAccessWaiters = [then]
        let home = NSHomeDirectory()
        Task {
            let readable = await Task.detached { FolderAccess.readableFolders(home: home) }.value
            let gained = FolderAccess.needsRestart(before: readableFolders, after: readable)
            readableFolders = readable
            panelController?.viewController.blockedFolders = FolderAccess.blocked(readable: readable)
            let waiters = folderAccessWaiters ?? []
            folderAccessWaiters = nil
            waiters.forEach { $0(gained) }
        }
    }

    /// Access granted in System Settings while BiuBiu runs shows up the next time the panel opens.
    private func recheckBlockedFolders() {
        guard sourcesStartedAt != .distantPast, folderAccessWaiters == nil,
              !FolderAccess.blocked(readable: readableFolders).isEmpty else { return }
        checkFolderAccess { [weak self] gainedAccess in
            guard let self, gainedAccess else { return }
            self.start(self.fileSource)
        }
    }

    /// Spotlight queries keep their start date, so restart them once an hour to move the window forward.
    private func restartSourcesIfStale() {
        if Date().timeIntervalSince(sourcesStartedAt) > 3600 { startSources() }
    }

    // MARK: - Settings changes

    /// `retryIfTaken` covers a restart: the copy being replaced can still own the shortcut for a moment.
    @discardableResult
    private func applyHotKey(retryIfTaken: Bool = false) -> Bool {
        hotKeys.unregister()
        guard let combo = settings.hotKey else {
            hotKeyWorking = true
            panelController?.viewController.hotKeyDisplay = nil
            return true
        }
        let ok = hotKeys.register(combo) { [weak self] in self?.togglePanel(fromStatusItem: false) }
        if !ok {
            Log.app.error("Could not register shortcut \(combo.displayString, privacy: .public)")
            if retryIfTaken {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    MainActor.assumeIsolated { _ = self?.applyHotKey() }
                }
            }
        }
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
                hotKeyChanged: { [weak self] in self?.applyHotKey() ?? false },
                hotKeyRecording: { [weak self] recording in
                    if recording { self?.hotKeys.unregister() } else { self?.applyHotKey() }
                },
                timeWindowChanged: { [weak self] in
                    guard let self else { return }
                    self.store.timeWindowDays = self.settings.timeWindowDays
                    self.startSources()
                },
                hiddenCategoriesChanged: { [weak self] in self?.panelController?.viewController.reloadCategories() }
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
        welcomeWindow = WelcomeWindowController(shortcut: hotKeyWorking ? settings.hotKey?.localizedDisplayString : nil) { [weak self] in
            self?.welcomeWindow = nil
            self?.startSources()
        }
        welcomeWindow?.present()
    }
}
