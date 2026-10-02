import AppKit
import BiuBiuCore

/// Made-up files, a store, pins and the real panel for the capture modes (`--screenshots`,
/// `--promo-sprites`), so nothing from the user's Mac ends up in a picture. Spotlight is not used.
@MainActor
final class DemoFixture {
    let directory: URL
    let language: String
    let settings: AppSettings
    let store: ActivityStore
    let pinStore: PinStore
    /// The timeline, newest first.
    private(set) var items: [ActivityItem] = []
    private var urlsByEnglishName: [String: URL] = [:]

    /// `extended` adds the two rows only the promo video needs.
    init(language: String, extended: Bool) {
        self.language = language
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("BiuBiuDemo-\(UUID().uuidString)")
        let now = Date()
        func ago(_ minutes: Double) -> Date { now.addingTimeInterval(-minutes * 60) }
        settings = AppSettings(defaults: UserDefaults(suiteName: "BiuBiuDemo-\(UUID().uuidString)")!)
        store = ActivityStore(ignoreRules: settings.ignoreRules, timeWindowDays: 7, homeDirectory: directory.path)
        pinStore = PinStore(fileURL: directory.appendingPathComponent("pins.json"))
        // Newest first. `file` is a method, so the list is built once the stored properties are set.
        let website = file("Projects", "官网改版", "官網改版", "Website Redesign", isFolder: true)
        _ = file("Documents", "年度预算.xlsx", "年度預算.xlsx", "Annual Budget.xlsx")  // pinned only
        var list: [ActivityItem] = [
            ActivityItem(url: file("Downloads", "产品手册-v2.pdf", "產品手冊-v2.pdf", "Product Guide v2.pdf"), kind: .file,
                         event: .downloaded, date: ago(2), sourceHost: "example.com"),
            ActivityItem(url: file("Documents", "季度汇报.pptx", "季度匯報.pptx", "Quarterly Review.pptx"), kind: .file,
                         event: .saved, date: ago(6)),
        ]
        if extended {
            list.append(ActivityItem(url: file("Projects/\(name("官网改版", "官網改版", "Website Redesign"))",
                                               "首页草稿.sketch", "首頁草稿.sketch", "Homepage Draft.sketch"),
                                     kind: .file, event: .opened, date: ago(11)))
        }
        list += [
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
        if extended {
            list.append(ActivityItem(url: file("Documents", "旅行计划.key", "旅行計畫.key", "Travel Plan.key"), kind: .file,
                                     event: .saved, date: ago(60 * 27)))
        }
        items = list
        store.update(sourceID: "demo", items: items)
    }

    /// Demo names: Simplified and Traditional Chinese get their own, everything else uses English names.
    private func name(_ zh: String, _ tw: String, _ en: String) -> String {
        language == "zh-Hans" ? zh : language == "zh-Hant" ? tw : en
    }

    /// Creates the demo file on disk, which gives it a real Finder icon, and remembers it by English name.
    @discardableResult
    func file(_ folder: String, _ zh: String, _ tw: String, _ en: String, isFolder: Bool = false) -> URL {
        let url = directory.appendingPathComponent(folder).appendingPathComponent(name(zh, tw, en))
        if isFolder {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        } else {
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: url.path, contents: Data())
        }
        urlsByEnglishName[en] = url
        return url
    }

    func url(_ englishName: String) -> URL { urlsByEnglishName[englishName]! }

    /// The real panel in a plain borderless window off screen, laid out and ready to draw in-process.
    /// (screencapture cannot grab the app's nonactivating panel; a plain window shows the same content.)
    func makePanel(hideScroller: Bool = false) -> (controller: PanelViewController, window: NSWindow) {
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
        controller.prepareForCapture(hideScroller: hideScroller)
        return (controller, window)
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: directory)
    }
}
