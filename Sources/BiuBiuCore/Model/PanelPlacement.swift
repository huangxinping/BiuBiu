import CoreGraphics

package enum PanelPlacement {
    package static let margin: CGFloat = 8

    /// Bottom-left origin for the panel, in screen coordinates.
    /// - anchor: the status item button frame when the panel should hang below it; nil to center at the top.
    package static func origin(panelSize: CGSize, anchor: CGRect?, visibleFrame: CGRect) -> CGPoint {
        let x: CGFloat
        let top: CGFloat
        if let anchor {
            x = anchor.midX - panelSize.width / 2
            top = anchor.minY - 4
        } else {
            x = visibleFrame.midX - panelSize.width / 2
            top = visibleFrame.maxY - margin
        }
        let minX = visibleFrame.minX + margin
        let maxX = visibleFrame.maxX - margin - panelSize.width
        let clampedX = min(max(x, minX), max(minX, maxX))
        let y = max(top - panelSize.height, visibleFrame.minY + margin)
        return CGPoint(x: clampedX, y: y)
    }
}
