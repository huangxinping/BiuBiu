import AppKit
import BiuBiuCore

/// `BiuBiu --promo-sprites <dir>` renders the real panel, in dark mode, in each state the promo video shows,
/// from DemoFixture's made-up files: `<state>.png` at 2x plus `layout.json` with every row's frame in points
/// (top-left origin). The BiuBiuPromo target animates these; run both through scripts/make-promo.sh.
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
        var searchField: [CGFloat] = []
        var segments: [CGFloat] = []
        var states: [String: [Row]] = [:]
    }

    static func run(outputDirectory: URL) -> Never {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.appearance = NSAppearance(named: .darkAqua)
        try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let demo = DemoFixture(language: "en", extended: true)
        let (controller, _) = demo.makePanel(hideScroller: true)
        let store = demo.store
        let quarterly = demo.url("Quarterly Review.pptx"), contract = demo.url("Contract Final.docx")
        let view = controller.view

        var layout = Layout()
        layout.size = [view.bounds.width, view.bounds.height]
        func frame(_ rect: NSRect) -> [CGFloat] {
            [rect.minX, view.bounds.height - rect.maxY, rect.width, rect.height]
        }

        func show(category: ActivityCategory = .all, search: String = "", items: [ActivityItem]? = nil) {
            if let items { store.update(sourceID: "demo", items: items) }
            store.category = category
            controller.reloadCategories()
            controller.setSearchText(search)
        }
        func snap(_ state: String) {
            let captured = controller.captureLayout()
            let image = ScreenshotMode.render(view, backdrop: NSColor(calibratedWhite: 0.13, alpha: 0.97))
            guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:]) else { return }
            try? png.write(to: outputDirectory.appendingPathComponent("\(state).png"))
            layout.states[state] = captured.rows.map { row in
                let title = switch row.row {
                case .pinnedHeader: "#pinned"
                case .sectionHeader(let kind): "#\(kind)"
                case .pinned(let entry): entry.displayName
                case .item(let item): item.displayName
                }
                return Layout.Row(title: title, frame: frame(row.frame), accessory: row.accessory.map(frame))
            }
            if layout.searchField.isEmpty {
                layout.searchField = frame(captured.searchField)
                layout.segments = frame(captured.segments)
            }
        }

        let withoutProjects = demo.items.filter { !$0.url.path.contains("/Projects") }
        let withoutDisk = withoutProjects.filter { $0.kind != .volume }
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
            { try? demo.pinStore.pin(url: quarterly); try? demo.pinStore.pin(url: contract); show() }, { snap("pinned") },
            { show(items: withoutProjects) }, { snap("ignored") },
            { show(items: withoutDisk) }, { snap("ejected") },
            {
                demo.pinStore.unpin(path: quarterly.path)
                demo.pinStore.unpin(path: contract.path)
                let promo = ActivityItem(url: demo.file("Desktop", "BiuBiu Promo.mp4", "BiuBiu Promo.mp4", "BiuBiu Promo.mp4"),
                                         kind: .file, event: .opened, date: Date())
                show(items: [promo] + withoutDisk)
            },
            { snap("twist") },
            {
                if let data = try? JSONEncoder().encode(layout) {
                    try? data.write(to: outputDirectory.appendingPathComponent("layout.json"))
                }
                demo.cleanUp()
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
