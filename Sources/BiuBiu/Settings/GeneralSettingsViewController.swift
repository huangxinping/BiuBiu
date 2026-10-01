import AppKit
import BiuBiuCore

@MainActor
final class GeneralSettingsViewController: NSViewController {
    struct Callbacks {
        let hotKeyChanged: (HotKeyCombo?) -> Bool
        let hotKeyRecording: (Bool) -> Void
        let timeWindowChanged: (Int) -> Void
        let hiddenCategoriesChanged: (Set<ActivityCategory>) -> Void
    }

    private let settings: AppSettings
    private let callbacks: Callbacks
    private let hotKeyWorking: Bool
    private let hotKeyWarning = NSTextField(wrappingLabelWithString: "")
    private let launchError = NSTextField(wrappingLabelWithString: "")
    private let launchCheckbox = NSButton(checkboxWithTitle: L("Open BiuBiu at login"), target: nil, action: nil)
    private let windowPopup = NSPopUpButton()
    private var categoryBoxes: [ActivityCategory: NSButton] = [:]
    private var grid: NSGridView?
    private static let hotKeyWarningRow = 1
    private static let launchErrorRow = 3

    /// `hotKeyWorking` is false when the saved shortcut could not be registered at launch.
    init(settings: AppSettings, hotKeyWorking: Bool, callbacks: Callbacks) {
        self.settings = settings
        self.hotKeyWorking = hotKeyWorking
        self.callbacks = callbacks
        super.init(nibName: nil, bundle: nil)
        title = L("General")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func loadView() {
        let recorder = HotKeyRecorder(combo: settings.hotKey)
        recorder.onRecordingChanged = callbacks.hotKeyRecording
        recorder.onChange = { [weak self] combo in
            guard let self else { return }
            let ok = self.callbacks.hotKeyChanged(combo)
            self.setMessageRow(Self.hotKeyWarningRow, label: self.hotKeyWarning, visible: !ok)
        }
        hotKeyWarning.stringValue = L("This shortcut is unavailable. Choose another one.")
        hotKeyWarning.textColor = .systemRed
        hotKeyWarning.font = .systemFont(ofSize: 11)
        hotKeyWarning.isHidden = hotKeyWorking

        launchCheckbox.target = self
        launchCheckbox.action = #selector(launchToggled)
        launchCheckbox.state = LaunchAtLogin.isEnabled ? .on : .off
        launchError.textColor = .systemRed
        launchError.font = .systemFont(ofSize: 11)
        launchError.isHidden = true

        for days in AppSettings.timeWindowOptions {
            windowPopup.addItem(withTitle: days == 1 ? L("1 day") : String(format: L("%d days"), days))
            windowPopup.lastItem?.tag = days
        }
        windowPopup.selectItem(withTag: settings.timeWindowDays)
        windowPopup.target = self
        windowPopup.action = #selector(windowChanged)

        let hidden = settings.hiddenCategories
        let boxes = ActivityCategory.allCases.filter { $0 != .all }.map { category -> NSButton in
            let box = NSButton(checkboxWithTitle: L(category.titleKey), target: self, action: #selector(categoriesChanged))
            box.state = hidden.contains(category) ? .off : .on
            categoryBoxes[category] = box
            return box
        }
        let categoryStack = NSStackView(views: boxes)
        categoryStack.orientation = .vertical
        categoryStack.alignment = .leading

        let grid = NSGridView(views: [
            [NSTextField(labelWithString: L("Shortcut:")), recorder],
            [NSGridCell.emptyContentView, hotKeyWarning],
            [NSTextField(labelWithString: L("Startup:")), launchCheckbox],
            [NSGridCell.emptyContentView, launchError],
            [NSTextField(labelWithString: L("Show items from the last:")), windowPopup],
            [NSTextField(labelWithString: L("Categories:")), categoryStack],
        ])
        grid.column(at: 0).xPlacement = .trailing
        grid.rowAlignment = .firstBaseline
        grid.rowSpacing = 10
        grid.columnSpacing = 8
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.row(at: Self.hotKeyWarningRow).isHidden = hotKeyWorking
        grid.row(at: Self.launchErrorRow).isHidden = true
        self.grid = grid

        let container = NSView()
        container.addSubview(grid)
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 480),
            grid.topAnchor.constraint(equalTo: container.topAnchor, constant: 24),
            grid.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -24),
            grid.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            grid.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 20),
            hotKeyWarning.widthAnchor.constraint(lessThanOrEqualToConstant: 260),
            launchError.widthAnchor.constraint(lessThanOrEqualToConstant: 260),
        ])
        view = container
    }

    @objc private func launchToggled() {
        do {
            try LaunchAtLogin.setEnabled(launchCheckbox.state == .on)
            setMessageRow(Self.launchErrorRow, label: launchError, visible: false)
        } catch {
            launchCheckbox.state = LaunchAtLogin.isEnabled ? .on : .off
            launchError.stringValue = error.localizedDescription
            setMessageRow(Self.launchErrorRow, label: launchError, visible: true)
        }
    }

    /// Message rows take no space while hidden; the window grows or shrinks to match.
    private func setMessageRow(_ row: Int, label: NSTextField, visible: Bool) {
        label.isHidden = !visible
        grid?.row(at: row).isHidden = !visible
        (parent as? SettingsTabViewController)?.fitWindowToSelectedTab()
    }

    @objc private func windowChanged() {
        callbacks.timeWindowChanged(windowPopup.selectedTag())
    }

    @objc private func categoriesChanged() {
        let hidden = Set(categoryBoxes.filter { $0.value.state == .off }.map(\.key))
        callbacks.hiddenCategoriesChanged(hidden)
    }
}
