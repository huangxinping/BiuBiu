import AppKit

final class HeaderCellView: NSTableCellView {
    private let label = NSTextField(labelWithString: "")
    private let chevron = NSImageView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .secondaryLabelColor
        chevron.contentTintColor = .secondaryLabelColor
        let stack = NSStackView(views: [label, chevron])
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 2),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// `collapsed` is nil for headers that cannot collapse.
    func configure(title: String, collapsed: Bool?) {
        label.stringValue = title
        chevron.isHidden = collapsed == nil
        let symbol = collapsed == true ? "chevron.right" : "chevron.down"
        chevron.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 9, weight: .semibold))
    }
}

final class ItemCellView: NSTableCellView {
    private let icon = NSImageView()
    private let title = NSTextField(labelWithString: "")
    private let subtitle = NSTextField(labelWithString: "")
    private let accessoryButton = NSButton()
    private var onAccessory: (() -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        icon.imageScaling = .scaleProportionallyUpOrDown
        title.font = .systemFont(ofSize: 13)
        title.lineBreakMode = .byTruncatingMiddle
        subtitle.font = .systemFont(ofSize: 11)
        subtitle.textColor = .secondaryLabelColor
        subtitle.lineBreakMode = .byTruncatingTail
        accessoryButton.bezelStyle = .accessoryBarAction
        accessoryButton.isBordered = false
        accessoryButton.target = self
        accessoryButton.action = #selector(accessoryClicked)

        let texts = NSStackView(views: [title, subtitle])
        texts.orientation = .vertical
        texts.alignment = .leading
        texts.spacing = 0
        let row = NSStackView(views: [icon, texts, accessoryButton])
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        texts.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addSubview(row)
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 22),
            icon.heightAnchor.constraint(equalToConstant: 22),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    struct Accessory {
        let symbol: String
        let toolTip: String
        let action: () -> Void
    }

    func configure(icon image: NSImage?, title: String, subtitle: String, dimmed: Bool,
                   toolTip: String?, accessory: Accessory?) {
        icon.image = image
        self.title.stringValue = title
        self.subtitle.stringValue = subtitle
        alphaValue = dimmed ? 0.5 : 1
        self.toolTip = toolTip
        onAccessory = accessory?.action
        accessoryButton.isHidden = accessory == nil
        accessoryButton.image = accessory.flatMap { NSImage(systemSymbolName: $0.symbol, accessibilityDescription: $0.toolTip) }
        accessoryButton.toolTip = accessory?.toolTip
    }

    @objc private func accessoryClicked() { onAccessory?() }
}
