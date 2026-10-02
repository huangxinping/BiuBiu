import AppKit
import Quartz

// The data source and delegate methods are nonisolated (their protocols are not main-actor annotated on
// every SDK) and step onto the main actor, where Quick Look always calls them.
extension PanelViewController: QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    func toggleQuickLook() {
        guard selectedPanelRow?.url != nil else { return }
        let panel = QLPreviewPanel.shared()!
        if QLPreviewPanel.sharedPreviewPanelExists(), panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.makeKeyAndOrderFront(nil)
        }
    }

    // Quick Look finds these through the responder chain. AppKit always calls them on the main thread.
    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool { true }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        MainActor.assumeIsolated {
            panel.dataSource = self
            panel.delegate = self
            panel.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        }
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        MainActor.assumeIsolated {
            panel.dataSource = nil
            panel.delegate = nil
            view.window?.makeKey()
        }
    }

    nonisolated func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        MainActor.assumeIsolated { selectedPanelRow?.url == nil ? 0 : 1 }
    }

    nonisolated func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        let url = MainActor.assumeIsolated { selectedPanelRow?.url }
        return url as NSURL?
    }

    /// Arrow keys inside Quick Look move the panel's selection, like Finder.
    nonisolated func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        guard event.type == .keyDown, event.keyCode == 125 || event.keyCode == 126 else { return false }
        let step = event.keyCode == 125 ? 1 : -1
        MainActor.assumeIsolated {
            moveSelection(by: step)
            panel.reloadData()
        }
        return true
    }
}
