import AppKit
import BiuBiuCore

/// `BiuBiu --promo-sprites <dir>` renders the real panel, in dark mode, in each state the promo video shows,
/// from made-up demo files: `<state>.png` at 2x plus `layout.json` with every row's frame in points (top-left
/// origin). The BiuBiuPromo target animates these; run both through scripts/make-promo.sh.
@MainActor
enum PromoSpritesMode {
    private struct Layout: Encodable {
        struct Row: Encodable {
            let title: String
            let frame: [CGFloat]
            /// The row's button (⏏ for drives), when it shows one.
            let accessory: [CGFloat]?
        }
        var size: [CGFloat] = []
        var hotKey = ""
        var searchField: [CGFloat] = []
        var segments: [CGFloat] = []
        var states: [String: [Row]] = [:]
    }

    static func run(outputDirectory: URL) -> Never {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.appearance = NSAppearance(named: .darkAqua)
        let demo = FileManager.default.temporaryDirectory.appendingPathComponent("BiuBiuPromo-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        func file(_ folder: String, _ name: String, isFolder: Bool = false) -> URL {
            let url = demo.appendingPathComponent(folder).appendingPathComponent(name)
            if isFolder {
                try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            } else {
                try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                FileManager.default.createFile(atPath: url.path, contents: Data())
            }
            return url
        }
        let now = Date()
        func ago(_ minutes: Double) -> Date { now.addingTimeInterval(-minutes * 60) }
        let website = file("Projects", "Website Redesign", isFolder: true)
        let homepage = file("Projects/Website Redesign", "Homepage Draft.sketch")
        let quarterly = file("Documents", "Quarterly Review.pptx")
        let contract = file("Documents", "Contract Final.docx")
        let volume = ActivityItem(url: URL(fileURLWithPath: "/"), kind: .volume, event: .mounted, date: ago(25),
                                  displayName: "Backup", parentName: "")
        let base: [ActivityItem] = [
            ActivityItem(url: file("Downloads", "Product Guide v2.pdf"), kind: .file, event: .downloaded, date: ago(2),
                         sourceHost: "example.com"),
            ActivityItem(url: quarterly, kind: .file, event: .saved, date: ago(6)),
            ActivityItem(url: homepage, kind: .file, event: .opened, date: ago(11)),
            ActivityItem(url: file("Desktop", "Mockup v3.png"), kind: .file, event: .added, date: ago(18)),
            volume,
            ActivityItem(url: file("Downloads", "Assets.zip"), kind: .file, event: .downloaded, date: ago(41),
                         sourceHost: "files.example.com"),
            ActivityItem(url: website, kind: .folder, event: .opened, date: ago(95)),
            ActivityItem(url: file("Documents", "Meeting Notes.md"), kind: .file, event: .opened, date: ago(130)),
            ActivityItem(url: URL(fileURLWithPath: "/System/Applications/Calculator.app"), kind: .application,
                         event: .installed, date: ago(60 * 20), displayName: "Calculator"),
            ActivityItem(url: contract, kind: .file, event: .saved, date: ago(60 * 24)),
            ActivityItem(url: file("Downloads", "Invoice September.pdf"), kind: .file, event: .downloaded,
                         date: ago(60 * 26), sourceHost: "example.com"),
            ActivityItem(url: file("Documents", "Travel Plan.key"), kind: .file, event: .saved, date: ago(60 * 27)),
        ]

        let settings = AppSettings(defaults: UserDefaults(suiteName: "BiuBiuPromo-\(UUID().uuidString)")!)
        let store = ActivityStore(ignoreRules: settings.ignoreRules, timeWindowDays: 7, homeDirectory: demo.path)
        store.update(sourceID: "demo", items: base)
        let pinStore = PinStore(fileURL: demo.appendingPathComponent("pins.json"))
        let controller = PanelViewController(dependencies: .init(
            store: store, pinStore: pinStore, settings: settings, volumeSource: VolumeSource(),
            openSettings: {}, close: {}, updateIgnoreRules: { _ in }))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: PanelController.panelSize),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.backgroundColor = .clear
        window.isOpaque = false
        window.isReleasedWhenClosed = false
        window.contentViewController = controller
        window.setContentSize(PanelController.panelSize)
        controller.hotKeyDisplay = HotKeyCombo.defaultToggle.localizedDisplayString
        controller.spotlightStatus = .ok
        ScreenshotMode.offscreen(window)
        controller.willShow()
        (controller.view as? NSVisualEffectView)?.state = .inactive
        // The overlay scroller only shows while scrolling in the real panel.
        controller.tableView.enclosingScrollView?.hasVerticalScroller = false

        var layout = Layout()
        let view = controller.view
        func frame(_ rect: NSRect) -> [CGFloat] {
            [rect.minX, view.bounds.height - rect.maxY, rect.width, rect.height]
        }
        layout.size = [view.bounds.width, view.bounds.height]
        layout.hotKey = HotKeyCombo.defaultToggle.displayString

        func show(category: ActivityCategory = .all, search: String = "", items: [ActivityItem]? = nil) {
            if let items { store.update(sourceID: "demo", items: items) }
            store.category = category
            store.searchText = search
            controller.searchField.stringValue = search
            controller.reloadCategories()
            controller.reload(resetSelection: true, refreshPins: true)
        }
        func snap(_ state: String) {
            view.layoutSubtreeIfNeeded()
            controller.tableView.layoutSubtreeIfNeeded()
            let image = ScreenshotMode.render(view, backdrop: NSColor(calibratedWhite: 0.13, alpha: 0.97))
            guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:]) else { return }
            try? png.write(to: outputDirectory.appendingPathComponent("\(state).png"))
            let table = controller.tableView
            layout.states[state] = controller.rows.indices.map { index in
                let rect = table.convert(table.rect(ofRow: index), to: view)
                let title = switch controller.rows[index] {
                case .pinnedHeader: "#pinned"
                case .sectionHeader(let kind): "#\(kind)"
                case .pinned(let entry): entry.displayName
                case .item(let item): item.displayName
                }
                let button = (table.view(atColumn: 0, row: index, makeIfNecessary: false)?.subviews
                    .flatMap { [$0] + $0.subviews } ?? [])
                    .compactMap { $0 as? NSButton }.first { !$0.isHidden }
                return Layout.Row(title: title, frame: frame(rect),
                                  accessory: button.map { frame($0.convert($0.bounds, to: view)) })
            }
            if layout.searchField.isEmpty {
                layout.searchField = frame(controller.searchField.convert(controller.searchField.bounds, to: view))
                layout.segments = frame(controller.segmentsFrameInView)
            }
        }

        // Each step waits a moment so AppKit finishes laying out and loading file icons.
        var steps: [() -> Void] = [
            { show() }, { snap("all") },
        ]
        for category in [ActivityCategory.files, .folders, .downloads, .apps] {
            steps += [{ show(category: category) }, { snap(category.rawValue) }]
        }
        for (index, text) in ["i", "in", "inv"].enumerated() {
            steps += [{ show(search: text) }, { snap("search-\(index + 1)") }]
        }
        steps += [
            { try? pinStore.pin(url: quarterly); try? pinStore.pin(url: contract); show() }, { snap("pinned") },
            { show(items: base.filter { !$0.url.path.contains("/Projects") }) }, { snap("ignored") },
            { show(items: base.filter { !$0.url.path.contains("/Projects") && $0.kind != .volume }) }, { snap("ejected") },
            {
                pinStore.unpin(path: quarterly.path); pinStore.unpin(path: contract.path)
                let promo = ActivityItem(url: file("Desktop", "BiuBiu Promo.mp4"), kind: .file, event: .opened, date: now)
                show(items: [promo] + base.filter { !$0.url.path.contains("/Projects") && $0.kind != .volume })
            },
            { snap("twist") },
            {
                if let data = try? JSONEncoder().encode(layout) {
                    try? data.write(to: outputDirectory.appendingPathComponent("layout.json"))
                }
                try? FileManager.default.removeItem(at: demo)
                print("Wrote promo sprites to \(outputDirectory.path)")
                exit(0)
            },
        ]
        func next() {
            guard !steps.isEmpty else { return }
            let step = steps.removeFirst()
            step()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { MainActor.assumeIsolated { next() } }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { MainActor.assumeIsolated { next() } }
        app.run()
        exit(0)
    }
}
