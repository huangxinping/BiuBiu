import AppKit
import BiuBiuCore

@MainActor
final class PanelViewController: NSViewController {
    struct Dependencies {
        let store: ActivityStore
        let pinStore: PinStore
        let settings: AppSettings
        let volumeSource: VolumeSource
        let openSettings: () -> Void
        let close: () -> Void
        let updateIgnoreRules: (IgnoreRules) -> Void
    }

    let deps: Dependencies
    private(set) var rows: [PanelRow] = []
    private var visibleCategories: [ActivityCategory] = []
    private var transientMessage: String?
    private var messageTask: Task<Void, Never>?

    private let panelView: PanelView
    private var searchField: NSSearchField { panelView.searchField }
    private var segments: NSSegmentedControl { panelView.segments }
    private var banner: NSTextField { panelView.banner }
    private var emptyLabel: NSTextField { panelView.emptyLabel }
    private var footerLabel: NSTextField { panelView.footerLabel }
    var tableView: NSTableView { panelView.tableView }

    var spotlightStatus: SpotlightStatus = .searching { didSet { updateBanner(); updateEmptyState() } }
    /// Protected folders macOS doesn't let BiuBiu read; their files are missing from the list.
    var blockedFolders: [ProtectedFolder] = [] { didSet { updateBanner() } }
    var hotKeyDisplay: String? { didSet { updateFooter() } }

    init(dependencies: Dependencies) {
        deps = dependencies
        panelView = PanelView(size: PanelController.panelSize, searchPlaceholder: L("Search recent items"),
                              settingsTitle: L("Settings…"))
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func loadView() {
        searchField.target = self
        searchField.action = #selector(searchChanged)
        segments.target = self
        segments.action = #selector(segmentChanged)
        banner.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(bannerClicked)))
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.action = #selector(rowClicked)
        tableView.menu?.delegate = self
        panelView.settingsButton.target = self
        panelView.settingsButton.action = #selector(settingsClicked)
        view = panelView
        reloadCategories()
        updateFooter()
    }

    // MARK: - Capture modes

    struct CaptureLayout {
        struct Row {
            let row: PanelRow
            let frame: NSRect
            /// The row's button (⏏ for drives), when it shows one.
            let accessory: NSRect?
        }
        let searchField: NSRect
        let segments: NSRect
        let rows: [Row]
    }

    /// Where things are, in the view's coordinates, for `--screenshots` and `--promo-sprites`.
    func captureLayout() -> CaptureLayout {
        view.layoutSubtreeIfNeeded()
        tableView.layoutSubtreeIfNeeded()
        let rowFrames = rows.indices.map { index in
            let cell = tableView.view(atColumn: 0, row: index, makeIfNecessary: false) as? ItemCellView
            return CaptureLayout.Row(row: rows[index], frame: tableView.convert(tableView.rect(ofRow: index), to: view),
                                     accessory: cell?.accessoryFrame(in: view))
        }
        return CaptureLayout(searchField: searchField.convert(searchField.bounds, to: view),
                             segments: segments.convert(segments.bounds, to: view), rows: rowFrames)
    }

    func prepareForCapture(hideScroller: Bool) { panelView.prepareForCapture(hideScroller: hideScroller) }

    /// Types into the search field on the panel's behalf.
    func setSearchText(_ text: String) {
        searchField.stringValue = text
        deps.store.searchText = text
        reload(resetSelection: true, refreshPins: true)
    }

    // MARK: - Lifecycle

    func willShow() {
        reloadCategories()
        searchField.stringValue = ""
        deps.store.searchText = ""
        // Resolve pins (following moved files) once per opening, not on every keystroke.
        reload(resetSelection: true, refreshPins: true)
        view.window?.makeFirstResponder(searchField)
    }

    func storeDidChange() {
        guard view.window?.isVisible == true else { return }
        reload(resetSelection: false)
    }

    func reloadCategories() {
        visibleCategories = deps.settings.visibleCategories
        if !visibleCategories.contains(deps.store.category) { deps.store.category = .all }
        segments.segmentCount = visibleCategories.count
        for (index, category) in visibleCategories.enumerated() {
            segments.setLabel(L(category.titleKey), forSegment: index)
        }
        segments.selectedSegment = visibleCategories.firstIndex(of: deps.store.category) ?? 0
    }

    func reload(resetSelection: Bool, refreshPins: Bool = false) {
        let previous = selectedRow.flatMap { rows.indices.contains($0) ? rows[$0] : nil }
        rows = PanelRowsBuilder.rows(
            pins: deps.pinStore.entries(refresh: refreshPins),
            showPinned: deps.store.category == .all,
            pinnedCollapsed: deps.settings.pinnedCollapsed,
            searchText: deps.store.searchText,
            sections: deps.store.sections
        )
        tableView.reloadData()
        let keep = resetSelection ? nil : previous.flatMap { PanelRowsBuilder.index(of: $0, in: rows) }
        select(keep ?? PanelRowsBuilder.firstSelectable(in: rows))
        updateEmptyState()
    }

    // MARK: - Selection

    var selectedRow: Int? {
        let row = tableView.selectedRow
        return row >= 0 ? row : nil
    }

    var selectedPanelRow: PanelRow? { selectedRow.map { rows[$0] } }

    func select(_ index: Int?) {
        guard let index, rows.indices.contains(index) else {
            tableView.deselectAll(nil)
            return
        }
        tableView.selectRowIndexes([index], byExtendingSelection: false)
        tableView.scrollRowToVisible(index)
    }

    func moveSelection(by step: Int) {
        select(PanelRowsBuilder.nextSelectable(in: rows, from: selectedRow, step: step))
    }

    // MARK: - Keyboard

    /// Handles a key press in the panel. Returns true when the event was consumed.
    func handleKeyDown(_ event: NSEvent) -> Bool {
        guard let command = PanelKeyMap.command(keyCode: event.keyCode,
                                                modifiers: HotKeyModifiers(event.modifierFlags),
                                                searchIsEmpty: searchField.stringValue.isEmpty,
                                                isComposing: isComposingText) else { return false }
        switch command {
        case .moveDown: moveSelection(by: 1)
        case .moveUp: moveSelection(by: -1)
        case .open: openSelected()
        case .reveal: revealSelected()
        case .clearSearch:
            searchField.stringValue = ""
            searchChanged()
        case .close: deps.close()
        case .quickLook: toggleQuickLook()
        case .togglePin: togglePinSelected()
        case .copyPath: copyPathOfSelected()
        case .openSettings: deps.openSettings()
        case .selectCategory(let index): selectCategory(at: index)
        }
        return true
    }

    /// True while an input method (Pinyin, Japanese, …) has uncommitted text in the search field.
    private var isComposingText: Bool {
        (searchField.currentEditor() as? NSTextView)?.hasMarkedText() == true
    }

    private func selectCategory(at index: Int) {
        guard visibleCategories.indices.contains(index) else { return }
        segments.selectedSegment = index
        segmentChanged()
    }

    // MARK: - Actions

    @objc private func searchChanged() {
        deps.store.searchText = searchField.stringValue
        reload(resetSelection: true)
    }

    @objc private func segmentChanged() {
        let category = visibleCategories[segments.selectedSegment]
        deps.store.category = category
        deps.settings.lastCategory = category
        reload(resetSelection: true)
    }

    @objc private func settingsClicked() { deps.openSettings() }

    @objc private func rowClicked() {
        let row = tableView.clickedRow
        guard rows.indices.contains(row) else { return }
        if case .pinnedHeader(let collapsed) = rows[row] {
            deps.settings.pinnedCollapsed = !collapsed
            reload(resetSelection: false)
            return
        }
        openSelected()
    }

    func openSelected() {
        guard let row = selectedPanelRow else { return }
        guard let url = row.url else { return handleMissing(row) }
        switch ItemActions.open(url) {
        case .opened:
            deps.close()
        case .missing:
            handleMissing(row)
        case .failed:
            NSSound.beep()
            showMessage(String(format: L("Couldn’t open “%@”"), row.displayName ?? url.lastPathComponent))
        }
    }

    func revealSelected() {
        guard let url = selectedPanelRow?.url else { return }
        ItemActions.reveal(url)
        deps.close()
    }

    func copyPathOfSelected() {
        guard let url = selectedPanelRow?.url else { return }
        ItemActions.copyPath(url)
        showMessage(L("Path copied"))
    }

    func togglePinSelected() {
        guard let row = selectedPanelRow else { return }
        switch row {
        case .pinned(let entry):
            deps.pinStore.unpin(path: entry.pin.path)
        case .item(let item):
            do { _ = try deps.pinStore.togglePin(url: item.url) } catch { showMessage(error.localizedDescription) }
        case .pinnedHeader, .sectionHeader:
            return
        }
        reload(resetSelection: false)
    }

    func handleMissing(_ row: PanelRow) {
        NSSound.beep()
        switch row {
        case .item(let item):
            deps.store.remove(path: item.url.path)
            showMessage(String(format: L("“%@” no longer exists"), item.displayName))
        case .pinned(let entry):
            showMessage(String(format: L("Can’t find “%@”"), entry.displayName))
        case .pinnedHeader, .sectionHeader:
            break
        }
    }

    func eject(_ item: ActivityItem) {
        deps.volumeSource.eject(item.url) { [weak self] error in
            if let error {
                self?.showMessage(String(format: L("Couldn’t eject “%@”: %@"), item.displayName, error.localizedDescription))
            }
        }
    }

    // MARK: - Banner, empty state, footer

    func showMessage(_ text: String) {
        transientMessage = text
        updateBanner()
        messageTask?.cancel()
        messageTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.transientMessage = nil
            self?.updateBanner()
        }
    }

    private var currentBanner: PanelStatusText.Banner? {
        PanelStatusText.banner(transient: transientMessage, blockedFolders: blockedFolders, spotlight: spotlightStatus)
    }

    private func updateBanner() {
        let text: String? = switch currentBanner {
        case .message(let message): message
        case .folderAccess(let folders): folderAccessMessage(folders)
        case .spotlightProblem:
            L("Spotlight found nothing in your home folder. It may be excluded from indexing — check System Settings › Spotlight.")
        case nil: nil
        }
        banner.stringValue = text ?? ""
        banner.isHidden = text == nil
    }

    private func folderAccessMessage(_ folders: [ProtectedFolder]) -> String {
        let names = folders.map { folder in
            switch folder {
            case .desktop: L("Desktop")
            case .documents: L("Documents")
            case .downloads: L("Downloads")
            }
        }
        let list = ListFormatter()
        list.locale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")
        return String(format: L("BiuBiu isn’t allowed to read %@, so those files are missing. Click to allow it in System Settings."),
                      list.string(from: names) ?? names.joined(separator: ", "))
    }

    @objc private func bannerClicked() {
        guard case .folderAccess = currentBanner else { return }
        deps.close()
        AppInfo.openFolderAccessSettings()
    }

    private func updateEmptyState() {
        let state = PanelStatusText.emptyState(rowCount: rows.count, searchText: deps.store.searchText, spotlight: spotlightStatus)
        emptyLabel.isHidden = state == nil
        emptyLabel.stringValue = switch state {
        case .noMatches: L("No matches")
        case .loading: L("Loading…")
        case .nothingYet: L("Nothing recent yet")
        case nil: ""
        }
    }

    private func updateFooter() {
        footerLabel.stringValue = hotKeyDisplay.map { String(format: L("%@ to open"), $0) } ?? ""
    }
}

// MARK: - Table

extension PanelViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        rows[row].isSelectable ? 36 : 24
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        rows[row].isSelectable
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        switch rows[row] {
        case .pinnedHeader(let collapsed):
            let cell = reuse(HeaderCellView.self)
            cell.configure(title: L("Pinned"), collapsed: collapsed)
            return cell
        case .sectionHeader(let kind):
            let cell = reuse(HeaderCellView.self)
            cell.configure(title: L(kind.titleKey), collapsed: nil)
            return cell
        case .pinned(let entry):
            let cell = reuse(ItemCellView.self)
            let parent = entry.url?.deletingLastPathComponent().lastPathComponent
            cell.configure(icon: ItemActions.icon(for: entry.url), title: entry.displayName,
                           subtitle: entry.isMissing ? L("Not Found") : parent ?? "",
                           dimmed: entry.isMissing, toolTip: entry.url?.path ?? entry.pin.path,
                           accessory: entry.isMissing
                               ? .init(symbol: "xmark.circle", toolTip: L("Remove from Pinned")) { [weak self] in
                                   self?.deps.pinStore.unpin(path: entry.pin.path)
                                   self?.reload(resetSelection: false)
                               }
                               : nil)
            return cell
        case .item(let item):
            let cell = reuse(ItemCellView.self)
            cell.configure(icon: ItemActions.icon(for: item.url), title: item.displayName,
                           subtitle: subtitle(for: item), dimmed: false,
                           toolTip: item.sourceHost.map { String(format: L("Downloaded from %@"), $0) } ?? item.url.path,
                           accessory: item.kind == .volume
                               ? .init(symbol: "eject.fill", toolTip: L("Eject")) { [weak self] in self?.eject(item) }
                               : nil)
            return cell
        }
    }

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        guard rows[row].isSelectable, let url = rows[row].url else { return nil }
        return url as NSURL
    }

    private func subtitle(for item: ActivityItem) -> String {
        ItemSubtitle.compose(item: item, isPinned: deps.pinStore.isPinned(path: item.url.path),
                             eventLabel: L(item.event.labelKey),
                             relativeTime: item.date.map { RelativeTime.string(for: $0) })
    }

    private func reuse<T: NSTableCellView>(_ type: T.Type) -> T {
        let identifier = NSUserInterfaceItemIdentifier(String(describing: type))
        if let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? T { return cell }
        let cell = T(frame: .zero)
        cell.identifier = identifier
        return cell
    }
}
