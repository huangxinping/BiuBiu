import AppKit
import BiuBiuCore

extension PanelViewController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let index = tableView.clickedRow
        guard rows.indices.contains(index), rows[index].isSelectable else { return }
        select(index)
        let row = rows[index]

        if case .pinned(let entry) = row, entry.isMissing {
            menu.addItem(ClosureMenuItem(title: L("Remove from Pinned")) { [weak self] in
                self?.deps.pinStore.unpin(path: entry.pin.path)
                self?.reload(resetSelection: false)
            })
            return
        }
        guard let url = row.url else { return }

        menu.addItem(ClosureMenuItem(title: L("Open")) { [weak self] in self?.openSelected() })
        menu.addItem(openWithItem(for: url))
        menu.addItem(ClosureMenuItem(title: L("Show in Finder")) { [weak self] in self?.revealSelected() })
        menu.addItem(ClosureMenuItem(title: L("Quick Look")) { [weak self] in self?.toggleQuickLook() })
        menu.addItem(ClosureMenuItem(title: L("Copy Path")) { [weak self] in self?.copyPathOfSelected() })
        menu.addItem(.separator())

        let pinned = deps.pinStore.isPinned(path: url.path)
        menu.addItem(ClosureMenuItem(title: pinned ? L("Unpin") : L("Pin")) { [weak self] in self?.togglePinSelected() })

        if case .item(let item) = row {
            if item.kind == .file || item.kind == .folder {
                menu.addItem(ignoreItem(for: item))
            }
            if item.kind == .volume {
                menu.addItem(ClosureMenuItem(title: L("Eject")) { [weak self] in self?.eject(item) })
            }
        }
    }

    private func openWithItem(for url: URL) -> NSMenuItem {
        let item = NSMenuItem(title: L("Open With"), action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for app in ItemActions.applications(toOpen: url) {
            let name = FileManager.default.displayName(atPath: app.path)
            let appItem = ClosureMenuItem(title: name) { [weak self] in
                ItemActions.open(url, withApplicationAt: app)
                self?.deps.close()
            }
            let icon = NSWorkspace.shared.icon(forFile: app.path)
            icon.size = NSSize(width: 16, height: 16)
            appItem.image = icon
            submenu.addItem(appItem)
        }
        item.submenu = submenu
        item.isEnabled = !submenu.items.isEmpty
        return item
    }

    private func ignoreItem(for item: ActivityItem) -> NSMenuItem {
        let home = NSHomeDirectory()
        let parent = item.url.deletingLastPathComponent()
        let menuItem = NSMenuItem(title: L("Ignore"), action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        let fileTitle = item.kind == .folder ? L("This Folder") : L("This File")
        submenu.addItem(ClosureMenuItem(title: fileTitle) { [weak self] in
            self?.addIgnoreRule(.pathPrefix(IgnoreRule.abbreviate(item.url.path, homeDirectory: home)))
        })
        submenu.addItem(ClosureMenuItem(title: String(format: L("Everything in “%@”"), parent.lastPathComponent)) { [weak self] in
            self?.addIgnoreRule(.pathPrefix(IgnoreRule.abbreviate(parent.path, homeDirectory: home)))
        })
        let ext = item.url.pathExtension.lowercased()
        if item.kind == .file, !ext.isEmpty {
            submenu.addItem(ClosureMenuItem(title: String(format: L("All .%@ Files"), ext)) { [weak self] in
                self?.addIgnoreRule(.fileExtension(ext))
            })
        }
        menuItem.submenu = submenu
        return menuItem
    }

    private func addIgnoreRule(_ rule: IgnoreRule) {
        var rules = deps.store.ignoreRules
        guard !rules.rules.contains(rule) else { return }
        rules.rules.append(rule)
        deps.updateIgnoreRules(rules)
    }
}
