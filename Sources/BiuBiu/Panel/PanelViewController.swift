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

    let searchField = NSSearchField()
    private let segments = NSSegmentedControl()
    private let banner = NSTextField(wrappingLabelWithString: "")
    let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let emptyLabel = NSTextField(labelWithString: "")
    private let footerLabel = NSTextField(labelWithString: "")

    var spotlightStatus: SpotlightStatus = .searching { didSet { updateBanner(); updateEmptyState() } }
    var hotKeyDisplay: String? { didSet { updateFooter() } }

    init(dependencies: Dependencies) {
        deps = dependencies
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    // MARK: - Building the view

    override func loadView() {
        let background = NSVisualEffectView(frame: NSRect(origin: .zero, size: PanelController.panelSize))
        background.material = .popover
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 12
        background.layer?.masksToBounds = true

        searchField.placeholderString = L("Search recent items")
        searchField.target = self
        searchField.action = #selector(searchChanged)
        searchField.sendsSearchStringImmediately = true

        segments.segmentStyle = .automatic
        segments.controlSize = .small
        segments.trackingMode = .selectOne
        // Equal widths would size every segment like "Downloads" and push the panel past 360 points.
        segments.segmentDistribution = .fillProportionally
        segments.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        segments.target = self
        segments.action = #selector(segmentChanged)

        banner.font = .systemFont(ofSize: 11)
        banner.textColor = .systemOrange
        banner.isHidden = true

        let column = NSTableColumn(identifier: .init("main"))
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.style = .plain
        tableView.backgroundColor = .clear
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.allowsEmptySelection = true
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.action = #selector(rowClicked)
        tableView.setDraggingSourceOperationMask(.copy, forLocal: false)
        tableView.menu = NSMenu()
        tableView.menu?.delegate = self

        scrollView.documentView = tableView
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.alignment = .center
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(emptyLabel)

        footerLabel.font = .systemFont(ofSize: 11)
        footerLabel.textColor = .secondaryLabelColor
        let gear = NSButton(image: NSImage(systemSymbolName: "gearshape", accessibilityDescription: L("Settings…"))!,
                            target: self, action: #selector(settingsClicked))
        gear.isBordered = false
        let footer = NSStackView(views: [footerLabel, NSView(), gear])

        let stack = NSStackView(views: [searchField, segments, banner, scrollView, footer])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 10, bottom: 8, right: 10)
        stack.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stack)
        for view in [searchField, segments, banner, scrollView, footer] {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -20).isActive = true
        }
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: background.topAnchor),
            stack.bottomAnchor.constraint(equalTo: background.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            emptyLabel.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
        ])
        scrollView.setContentHuggingPriority(.defaultLow, for: .vertical)
        view = background
        reloadCategories()
        updateFooter()
    }

    // MARK: - Lifecycle

    func willShow() {
        reloadCategories()
        searchField.stringValue = ""
        deps.store.searchText = ""
        reload(resetSelection: true)
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

    func reload(resetSelection: Bool) {
        let previous = selectedRow.flatMap { rows.indices.contains($0) ? rows[$0].url : nil }
        rows = PanelRowsBuilder.rows(
            pins: deps.pinStore.entries(),
            showPinned: deps.store.category == .all,
            pinnedCollapsed: deps.settings.pinnedCollapsed,
            searchText: deps.store.searchText,
            sections: deps.store.sections
        )
        tableView.reloadData()
        let keep = resetSelection ? nil : previous.flatMap { url in rows.firstIndex { $0.url == url } }
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
        case .escape:
            if searchField.stringValue.isEmpty {
                deps.close()
            } else {
                searchField.stringValue = ""
                searchChanged()
            }
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
        guard let url = row.url, ItemActions.open(url) else {
            handleMissing(row)
            return
        }
        deps.close()
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
            if deps.pinStore.isPinned(path: item.url.path) {
                deps.pinStore.unpin(path: item.url.path)
            } else {
                do { try deps.pinStore.pin(url: item.url) } catch { showMessage(error.localizedDescription) }
            }
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

    private func updateBanner() {
        let spotlightProblem = spotlightStatus == .noResults || spotlightStatus == .failedToStart
        let text = transientMessage ?? (spotlightProblem
            ? L("Spotlight found nothing in your home folder. It may be excluded from indexing — check System Settings › Spotlight.")
            : nil)
        banner.stringValue = text ?? ""
        banner.isHidden = text == nil
    }

    private func updateEmptyState() {
        emptyLabel.isHidden = !rows.isEmpty
        if !deps.store.searchText.isEmpty {
            emptyLabel.stringValue = L("No matches")
        } else if spotlightStatus == .searching {
            emptyLabel.stringValue = L("Loading…")
        } else {
            emptyLabel.stringValue = L("Nothing recent yet")
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
