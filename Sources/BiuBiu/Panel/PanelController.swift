import AppKit
import BiuBiuCore
import Quartz

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    static let panelSize = NSSize(width: 360, height: 520)

    let viewController: PanelViewController
    private let panel = FloatingPanel(size: PanelController.panelSize)
    private var clickMonitor: Any?
    private var keyMonitor: Any?
    private var debouncer = PanelToggleDebouncer()
    var onWillShow: (() -> Void)?

    init(viewController: PanelViewController) {
        self.viewController = viewController
        super.init()
        panel.contentViewController = viewController
        panel.setContentSize(Self.panelSize)
        panel.delegate = self
    }

    var isVisible: Bool { panel.isVisible }

    func toggle(anchor: NSRect?) {
        if isVisible {
            hide()
        } else if debouncer.shouldReopen(at: Date()) {
            show(anchor: anchor)
        }
    }

    func show(anchor: NSRect?) {
        onWillShow?()
        let mouse = NSEvent.mouseLocation
        let point = anchor.map { NSPoint(x: $0.midX, y: $0.midY) } ?? mouse
        let screen = NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) } ?? NSScreen.main
        if let screen {
            panel.setFrameOrigin(PanelPlacement.origin(panelSize: panel.frame.size, anchor: anchor,
                                                       visibleFrame: screen.visibleFrame))
        }
        viewController.willShow()
        panel.makeKeyAndOrderFront(nil)
        panel.invalidateShadow()
        installMonitors()
    }

    func hide() {
        if isVisible { debouncer.panelDidHide(at: Date()) }
        removeMonitors()
        if QLPreviewPanel.sharedPreviewPanelExists(), QLPreviewPanel.shared().isVisible {
            QLPreviewPanel.shared().orderOut(nil)
        }
        panel.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        // Quick Look takes key focus while previewing; the panel stays put underneath it.
        if QLPreviewPanel.sharedPreviewPanelExists(), QLPreviewPanel.shared().isVisible { return }
        hide()
    }

    private func installMonitors() {
        removeMonitors()
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.hide() }
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.panel else { return event }
            return self.viewController.handleKeyDown(event) ? nil : event
        }
    }

    private func removeMonitors() {
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        clickMonitor = nil
        keyMonitor = nil
    }
}
