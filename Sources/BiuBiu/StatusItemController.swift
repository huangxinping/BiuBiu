import AppKit

@MainActor
final class StatusItemController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let onToggle: () -> Void
    private let menu = NSMenu()

    init(onToggle: @escaping () -> Void, onSettings: @escaping () -> Void, onQuit: @escaping () -> Void) {
        self.onToggle = onToggle
        super.init()
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: "BiuBiu")
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(buttonClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        menu.addItem(ClosureMenuItem(title: L("Settings…"), keyEquivalent: ",", handler: onSettings))
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem(title: L("Quit BiuBiu"), keyEquivalent: "q", handler: onQuit))
    }

    /// The status button's frame in screen coordinates.
    var buttonScreenFrame: NSRect? {
        guard let button = item.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    /// The button frame, but only when the menu bar is showing on the screen under the mouse.
    /// In a full-screen space the menu bar is hidden, and the panel should drop from the top center instead.
    func visibleAnchor(onScreenContaining point: NSPoint) -> NSRect? {
        guard let frame = buttonScreenFrame,
              let window = item.button?.window,
              window.occlusionState.contains(.visible),
              let screen = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) }),
              screen.frame.contains(NSPoint(x: frame.midX, y: frame.midY)) else { return nil }
        return frame
    }

    @objc private func buttonClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            item.menu = menu
            item.button?.performClick(nil)
            item.menu = nil
        } else {
            onToggle()
        }
    }
}

/// An NSMenuItem that runs a closure.
final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, keyEquivalent: String = "", handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: keyEquivalent)
        target = self
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is not used") }

    @objc private func fire() { handler() }
}
