import AppKit
import BiuBiuCore

@MainActor
final class IgnoreRulesViewController: NSViewController {
    private var rules: IgnoreRules
    private let onChange: (IgnoreRules) -> Void
    private let tableView = NSTableView()
    private let typePopup = NSPopUpButton()
    private let valueField = NSTextField()
    private let hiddenCheckbox = NSButton(checkboxWithTitle: L("Ignore hidden files and folders"), target: nil, action: nil)

    private static let typeTitles = [L("Path and everything inside"), L("Path contains"), L("File extension")]

    init(rules: IgnoreRules, onChange: @escaping (IgnoreRules) -> Void) {
        self.rules = rules
        self.onChange = onChange
        super.init(nibName: nil, bundle: nil)
        title = L("Ignore")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// Called when rules change elsewhere (for example from the panel's context menu).
    func update(rules newRules: IgnoreRules) {
        rules = newRules
        hiddenCheckbox.state = rules.ignoreHidden ? .on : .off
        tableView.reloadData()
    }

    override func loadView() {
        for (identifier, title, width) in [("type", L("Type"), 170.0), ("value", L("Value"), 250.0)] {
            let column = NSTableColumn(identifier: .init(identifier))
            column.title = title
            column.width = width
            tableView.addTableColumn(column)
        }
        tableView.dataSource = self
        tableView.delegate = self
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        let scroll = NSScrollView()
        scroll.documentView = tableView
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder

        typePopup.addItems(withTitles: Self.typeTitles)
        valueField.placeholderString = L("e.g. ~/Projects/old or tmp")
        let addButton = NSButton(title: L("Add"), target: self, action: #selector(addRule))
        let removeButton = NSButton(title: L("Remove"), target: self, action: #selector(removeSelected))
        let restoreButton = NSButton(title: L("Restore Defaults"), target: self, action: #selector(restoreDefaults))
        hiddenCheckbox.target = self
        hiddenCheckbox.action = #selector(hiddenToggled)
        hiddenCheckbox.state = rules.ignoreHidden ? .on : .off

        let addRow = NSStackView(views: [typePopup, valueField, addButton])
        let bottomRow = NSStackView(views: [removeButton, NSView(), restoreButton])
        let stack = NSStackView(views: [scroll, addRow, bottomRow, hiddenCheckbox])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        for view in [scroll, addRow, bottomRow] {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -40).isActive = true
        }
        NSLayoutConstraint.activate([
            stack.widthAnchor.constraint(equalToConstant: 480),
            scroll.heightAnchor.constraint(equalToConstant: 220),
            valueField.widthAnchor.constraint(greaterThanOrEqualToConstant: 140),
        ])
        valueField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view = stack
    }

    private func commit() {
        onChange(rules)
        tableView.reloadData()
    }

    @objc private func addRule() {
        let value = valueField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { NSSound.beep(); return }
        let rule: IgnoreRule = switch typePopup.indexOfSelectedItem {
        case 0: .pathPrefix(value)
        case 1: .pathContains(value)
        default: .fileExtension(value)
        }
        guard !rules.rules.contains(rule) else { return }
        rules.rules.append(rule)
        valueField.stringValue = ""
        commit()
    }

    @objc private func removeSelected() {
        let selected = tableView.selectedRowIndexes
        guard !selected.isEmpty else { return }
        rules.rules = rules.rules.enumerated().filter { !selected.contains($0.offset) }.map(\.element)
        commit()
    }

    @objc private func restoreDefaults() {
        rules = .defaults
        hiddenCheckbox.state = .on
        commit()
    }

    @objc private func hiddenToggled() {
        rules.ignoreHidden = hiddenCheckbox.state == .on
        commit()
    }

    private static func typeTitle(_ rule: IgnoreRule) -> String {
        switch rule {
        case .pathPrefix: typeTitles[0]
        case .pathContains: typeTitles[1]
        case .fileExtension: typeTitles[2]
        }
    }
}

extension IgnoreRulesViewController: NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int { rules.rules.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let rule = rules.rules[row]
        let isValue = tableColumn?.identifier.rawValue == "value"
        let field = NSTextField(string: isValue ? rule.value : Self.typeTitle(rule))
        field.isBordered = false
        field.drawsBackground = false
        field.isEditable = isValue
        field.delegate = isValue ? self : nil
        return field
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        guard let field = notification.object as? NSTextField else { return }
        let row = tableView.row(for: field)
        guard rules.rules.indices.contains(row) else { return }
        let value = field.stringValue.trimmingCharacters(in: .whitespaces)
        if value.isEmpty {
            rules.rules.remove(at: row)
        } else {
            rules.rules[row] = rules.rules[row].withValue(value)
        }
        commit()
    }
}
