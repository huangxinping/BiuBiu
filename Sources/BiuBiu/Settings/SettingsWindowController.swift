import AppKit
import BiuBiuCore

/// Sizes the window to the selected page, so each page decides its own height instead of all of them
/// sharing one oversized window.
@MainActor
final class SettingsTabViewController: NSTabViewController {
    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        fitWindowToSelectedTab()
    }

    func fitWindowToSelectedTab() {
        guard let window = view.window,
              let page = tabViewItems[safe: selectedTabViewItemIndex]?.viewController?.view else { return }
        page.layoutSubtreeIfNeeded()
        let top = window.frame.maxY
        window.setContentSize(page.fittingSize)
        window.setFrameTopLeftPoint(NSPoint(x: window.frame.minX, y: top))
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

@MainActor
final class SettingsWindowController: NSWindowController {
    let ignoreRulesViewController: IgnoreRulesViewController

    init(general: GeneralSettingsViewController, ignoreRules: IgnoreRulesViewController) {
        ignoreRulesViewController = ignoreRules
        let tabs = SettingsTabViewController()
        tabs.tabStyle = .toolbar
        tabs.canPropagateSelectedChildViewControllerTitle = false
        for (controller, symbol) in [(general as NSViewController, "gearshape"),
                                     (ignoreRules, "eye.slash"),
                                     (AboutViewController(), "info.circle")] {
            let item = NSTabViewItem(viewController: controller)
            item.label = controller.title ?? ""
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            tabs.addTabViewItem(item)
        }
        let window = NSWindow(contentViewController: tabs)
        window.title = L("BiuBiu Settings")
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func present() {
        (window?.contentViewController as? SettingsTabViewController)?.fitWindowToSelectedTab()
        window?.center()
        NSApp.activate()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
