import AppKit

/// The panel's controls and layout. PanelViewController owns the behavior (targets, data source, state).
@MainActor
final class PanelView: NSVisualEffectView {
    let searchField = NSSearchField()
    let segments = NSSegmentedControl()
    let banner = NSTextField(wrappingLabelWithString: "")
    let tableView = NSTableView()
    let scrollView = NSScrollView()
    let emptyLabel = NSTextField(labelWithString: "")
    let footerLabel = NSTextField(labelWithString: "")
    let settingsButton: NSButton

    init(size: NSSize, searchPlaceholder: String, settingsTitle: String) {
        settingsButton = NSButton(image: NSImage(systemSymbolName: "gearshape", accessibilityDescription: settingsTitle)!,
                                  target: nil, action: nil)
        super.init(frame: NSRect(origin: .zero, size: size))
        material = .popover
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.masksToBounds = true

        searchField.placeholderString = searchPlaceholder
        searchField.sendsSearchStringImmediately = true

        segments.segmentStyle = .automatic
        segments.controlSize = .small
        segments.trackingMode = .selectOne
        // Equal widths would size every segment like "Downloads" and push the panel past 360 points.
        segments.segmentDistribution = .fillProportionally
        segments.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        banner.font = .systemFont(ofSize: 11)
        banner.textColor = .systemOrange
        banner.isHidden = true

        tableView.addTableColumn(NSTableColumn(identifier: .init("main")))
        tableView.headerView = nil
        tableView.style = .plain
        tableView.backgroundColor = .clear
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.allowsEmptySelection = true
        tableView.setDraggingSourceOperationMask(.copy, forLocal: false)
        tableView.menu = NSMenu()

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
        settingsButton.isBordered = false
        let footer = NSStackView(views: [footerLabel, NSView(), settingsButton])

        let stack = NSStackView(views: [searchField, segments, banner, scrollView, footer])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 10, bottom: 8, right: 10)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        for view in [searchField, segments, banner, scrollView, footer] {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -20).isActive = true
        }
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            emptyLabel.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
        ])
        scrollView.setContentHuggingPriority(.defaultLow, for: .vertical)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// For drawing in-process (`--screenshots`, `--promo-sprites`): the frosted material only renders on
    /// screen, so a flat one reads closer to the real thing. The real panel's overlay scroller only shows
    /// while scrolling, so the promo hides it.
    func prepareForCapture(hideScroller: Bool) {
        state = .inactive
        if hideScroller { scrollView.hasVerticalScroller = false }
    }
}
