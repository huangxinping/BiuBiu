import AppKit
import BiuBiuCore

/// `BiuBiu --screenshots <dir>` renders the README screenshots from made-up demo files, offscreen, so no
/// one's real files end up in a picture. Spotlight is not used. Run it through scripts/make-screenshots.sh.
@MainActor
enum ScreenshotMode {
    private struct DemoFile {
        let path: String
        let zh: String
        let en: String
    }

    static func run(outputDirectory: URL) -> Never {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let language = RelativeTime.localization
        let suffix = language
        /// Demo names: Simplified and Traditional Chinese get their own, everything else uses English names.
        func name(_ zh: String, _ tw: String, _ en: String) -> String {
            language == "zh-Hans" ? zh : language == "zh-Hant" ? tw : en
        }
        let demo = FileManager.default.temporaryDirectory.appendingPathComponent("BiuBiuDemo-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        // Demo files on disk give real Finder icons; their names are invented.
        func file(_ folder: String, _ zh: String, _ tw: String, _ en: String, folderItem: Bool = false) -> URL {
            let url = demo.appendingPathComponent(folder).appendingPathComponent(name(zh, tw, en))
            if folderItem {
                try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            } else {
                try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                FileManager.default.createFile(atPath: url.path, contents: Data())
            }
            return url
        }
        let now = Date()
        func ago(_ minutes: Double) -> Date { now.addingTimeInterval(-minutes * 60) }
        let website = file("Projects", "官网改版", "官網改版", "Website Redesign", folderItem: true)
        let budget = file("Documents", "年度预算.xlsx", "年度預算.xlsx", "Annual Budget.xlsx")
        let items: [ActivityItem] = [
            ActivityItem(url: file("Downloads", "产品手册-v2.pdf", "產品手冊-v2.pdf", "Product Guide v2.pdf"), kind: .file,
                         event: .downloaded, date: ago(2), sourceHost: "example.com"),
            ActivityItem(url: file("Documents", "季度汇报.pptx", "季度匯報.pptx", "Quarterly Review.pptx"), kind: .file,
                         event: .saved, date: ago(6)),
            ActivityItem(url: file("Desktop", "设计稿 v3.png", "設計稿 v3.png", "Mockup v3.png"), kind: .file, event: .added, date: ago(18)),
            ActivityItem(url: URL(fileURLWithPath: "/"), kind: .volume, event: .mounted, date: ago(25),
                         displayName: name("备份盘", "備份碟", "Backup"), parentName: ""),
            ActivityItem(url: file("Downloads", "素材包.zip", "素材包.zip", "Assets.zip"), kind: .file,
                         event: .downloaded, date: ago(41), sourceHost: "files.example.com"),
            ActivityItem(url: website, kind: .folder, event: .opened, date: ago(95)),
            ActivityItem(url: file("Documents", "会议纪要.md", "會議紀要.md", "Meeting Notes.md"), kind: .file, event: .opened, date: ago(130)),
            ActivityItem(url: URL(fileURLWithPath: "/System/Applications/Calculator.app"), kind: .application,
                         event: .installed, date: ago(60 * 20), displayName: name("计算器", "計算機", "Calculator")),
            ActivityItem(url: file("Documents", "合同-终版.docx", "合約-終版.docx", "Contract Final.docx"), kind: .file,
                         event: .saved, date: ago(60 * 24)),
            ActivityItem(url: file("Downloads", "发票-九月.pdf", "發票-九月.pdf", "Invoice September.pdf"), kind: .file,
                         event: .downloaded, date: ago(60 * 26), sourceHost: "example.com"),
        ]

        let settings = AppSettings(defaults: UserDefaults(suiteName: "BiuBiuScreenshots-\(UUID().uuidString)")!)
        let store = ActivityStore(ignoreRules: settings.ignoreRules, timeWindowDays: 7, homeDirectory: demo.path)
        store.update(sourceID: "demo", items: items)
        let pinStore = PinStore(fileURL: demo.appendingPathComponent("pins.json"))
        try? pinStore.pin(url: website)
        try? pinStore.pin(url: budget)

        let panelController = PanelViewController(dependencies: .init(
            store: store, pinStore: pinStore, settings: settings, volumeSource: VolumeSource(),
            openSettings: {}, close: {}, updateIgnoreRules: { _ in }))
        // A plain borderless window shows the same content; screencapture cannot grab the nonactivating panel.
        let panel = NSWindow(contentRect: NSRect(origin: .zero, size: PanelController.panelSize),
                             styleMask: [.borderless], backing: .buffered, defer: false)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.isReleasedWhenClosed = false
        panel.contentViewController = panelController
        panel.setContentSize(PanelController.panelSize)
        panelController.hotKeyDisplay = HotKeyCombo.defaultToggle.localizedDisplayString
        panelController.spotlightStatus = .ok
        offscreen(panel)
        panelController.willShow()
        // In-process drawing cannot show the frosted material; a flat material reads closer to the real thing.
        (panelController.view as? NSVisualEffectView)?.state = .inactive

        let general = GeneralSettingsViewController(settings: settings, hotKeyWorking: true, callbacks: .init(
            hotKeyChanged: { _ in true }, hotKeyRecording: { _ in }, timeWindowChanged: { _ in },
            hiddenCategoriesChanged: { _ in }, languageChanged: { _ in }))
        let ignore = IgnoreRulesViewController(rules: settings.ignoreRules) { _ in }
        let settingsWindow = SettingsWindowController(general: general, ignoreRules: ignore).window!

        func shoot(after delay: Double, _ work: @escaping @MainActor () -> Void) {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { MainActor.assumeIsolated(work) }
        }
        shoot(after: 0.8) {
            write(compose(render(panelController.view), menuBar: true),
                  to: outputDirectory.appendingPathComponent("panel-\(suffix).jpg"))
            store.category = .downloads
            panelController.reloadCategories()
            panelController.reload(resetSelection: true)
        }
        shoot(after: 1.6) {
            write(compose(render(panelController.view), menuBar: true),
                  to: outputDirectory.appendingPathComponent("downloads-\(suffix).jpg"))
            panel.orderOut(nil)
            (settingsWindow.contentViewController as? SettingsTabViewController)?.fitWindowToSelectedTab()
            offscreen(settingsWindow)
        }
        shoot(after: 2.4) {
            write(compose(capture(settingsWindow), menuBar: false),
                  to: outputDirectory.appendingPathComponent("settings-\(suffix).jpg"))
            try? FileManager.default.removeItem(at: demo)
            exit(0)
        }
        app.run()
        exit(0)
    }

    private static func offscreen(_ window: NSWindow) {
        window.setFrameOrigin(NSPoint(x: -6000, y: -6000))
        window.orderFrontRegardless()
    }

    /// Draws a view in-process at 2x. screencapture cannot grab a borderless offscreen window, and the
    /// panel's frosted material does not draw this way, so the panel backdrop is painted underneath.
    private static func render(_ view: NSView) -> NSImage {
        view.layoutSubtreeIfNeeded()
        let size = view.bounds.size
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * 2), pixelsHigh: Int(size.height * 2),
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let shape = NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: 12, yRadius: 12)
        NSColor(calibratedWhite: 0.965, alpha: 0.97).setFill()
        shape.fill()
        NSGraphicsContext.restoreGraphicsState()
        view.cacheDisplay(in: view.bounds, to: rep)
        let image = NSImage(size: size)
        image.addRepresentation(rep)
        return image
    }

    /// The window's own pixels, without the system shadow (compose() draws a softer one).
    private static func capture(_ window: NSWindow) -> NSImage {
        window.displayIfNeeded()
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("biubiu-shot-\(UUID().uuidString).png")
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = ["-x", "-o", "-l", "\(window.windowNumber)", file.path]
        try? task.run()
        task.waitUntilExit()
        defer { try? FileManager.default.removeItem(at: file) }
        guard let image = NSImage(contentsOf: file) else {
            FileHandle.standardError.write(Data("Could not capture a window. Is the display awake?\n".utf8))
            exit(1)
        }
        return image
    }

    /// Puts a window image on a gradient backdrop; panels hang below a sketched menu bar.
    private static func compose(_ window: NSImage, menuBar: Bool) -> NSBitmapImageRep {
        let size = menuBar ? NSSize(width: 760, height: 640) : NSSize(width: window.size.width + 200, height: window.size.height + 140)
        let scale: CGFloat = 2
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let canvas = NSRect(origin: .zero, size: size)
        NSGradient(starting: NSColor(calibratedRed: 0.42, green: 0.55, blue: 0.98, alpha: 1),
                   ending: NSColor(calibratedRed: 0.80, green: 0.47, blue: 0.86, alpha: 1))!.draw(in: canvas, angle: -35)

        var windowOrigin = NSPoint(x: (size.width - window.size.width) / 2, y: (size.height - window.size.height) / 2)
        if menuBar {
            let barHeight: CGFloat = 30
            let bar = NSRect(x: 0, y: size.height - barHeight, width: size.width, height: barHeight)
            NSColor(white: 1, alpha: 0.55).setFill()
            bar.fill()
            let clock = NSAttributedString(string: "9:41", attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .medium), .foregroundColor: NSColor.black])
            clock.draw(at: NSPoint(x: size.width - 52, y: bar.minY + 7))
            let symbols = ["battery.100percent", "wifi", "magnifyingglass"]
            var x = size.width - 84
            for name in symbols {
                draw(symbol: name, at: NSPoint(x: x, y: bar.midY), color: .black)
                x -= 32
            }
            // BiuBiu's item, highlighted as if just clicked.
            let itemRect = NSRect(x: x - 10, y: bar.minY + 3, width: 30, height: barHeight - 6)
            NSColor(white: 0, alpha: 0.12).setFill()
            NSBezierPath(roundedRect: itemRect, xRadius: 6, yRadius: 6).fill()
            draw(symbol: "clock.arrow.circlepath", at: NSPoint(x: itemRect.midX - 8, y: bar.midY), color: .black)
            windowOrigin = NSPoint(x: min(itemRect.midX - window.size.width / 2, size.width - window.size.width - 12),
                                   y: bar.minY - 6 - window.size.height)
        }
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(white: 0, alpha: 0.35)
        shadow.shadowBlurRadius = 24
        shadow.shadowOffset = NSSize(width: 0, height: -8)
        shadow.set()
        window.draw(in: NSRect(origin: windowOrigin, size: window.size))
        NSGraphicsContext.restoreGraphicsState()
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    private static func draw(symbol name: String, at point: NSPoint, color: NSColor) {
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 14, weight: .medium).applying(.init(paletteColors: [color])))
        else { return }
        image.draw(in: NSRect(x: point.x, y: point.y - image.size.height / 2, width: image.size.width, height: image.size.height))
    }

    private static func write(_ rep: NSBitmapImageRep, to url: URL) {
        // JPEG keeps the gradient backdrop small enough for the repository.
        try? rep.representation(using: .jpeg, properties: [.compressionFactor: 0.88])?.write(to: url)
        print("Wrote \(url.path)")
    }
}
