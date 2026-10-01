import Foundation

/// Remembers when the panel last closed, so a click that already closed it is not taken as a request
/// to reopen. Clicking the status item while the panel is open closes the panel on mouse-down (the
/// outside-click monitor sees it, because the system draws menu bar items), and the item's own action
/// then fires on mouse-up and would open the panel again.
package struct PanelToggleDebouncer {
    package static let window: TimeInterval = 0.4

    private var hiddenAt = Date.distantPast

    package init() {}

    package mutating func panelDidHide(at date: Date) {
        hiddenAt = date
    }

    package func shouldReopen(at date: Date) -> Bool {
        date.timeIntervalSince(hiddenAt) >= Self.window
    }
}
