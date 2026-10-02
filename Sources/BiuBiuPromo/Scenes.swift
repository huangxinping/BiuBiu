import AppKit

/// When things happen, in seconds. The soundtrack hits the same moments; the beat is 120 BPM from `drop`.
enum Cue {
    static let duration = 55.0
    static let lines = [0.4, 1.5, 2.6]
    static let rainStart = 3.8
    static let whereIsIt = 5.4
    static let freeze = 7.0
    static let press = 8.0
    static let secondBiu = 8.25
    static let drop = 10.0
    static let tabSwitches = [16.5, 17.0, 17.5, 18.0, 18.5]
    static let typing = [19.3, 19.55, 19.8]
    static let fullScreenIn = 21.0
    static let fullScreenPress = 22.45
    static let dragStart = 26.2
    static let drop2 = 27.3
    static let spacePress = 30.4
    static let pinPress = 34.0
    static let rightClick = 36.0
    static let ignoreClick = 37.0
    static let ejectClick = 38.9
    static let stamps = [42.0, 42.8, 43.6]
    static let hellos = 44.4
    static let oneMoreThing = 46.0
    static let twist = 47.0
    static let finale = 50.0
}

/// The storyboard: draws the frame at time `t`.
@MainActor
final class Storyboard {
    let canvas: Canvas
    let assets: Assets
    let panelScale: CGFloat = 1.55
    let panelOrigin: CGPoint

    init(canvas: Canvas, assets: Assets) {
        self.canvas = canvas
        self.assets = assets
        panelOrigin = CGPoint(x: Canvas.menuItemCenter.x - assets.panelSize.width * panelScale / 2, y: Canvas.menuBarHeight + 12)
    }

    func draw(_ t: Double) {
        switch t {
        case ..<Cue.freeze: coldOpen(t)
        case ..<Cue.drop: shortcut(t)
        case ..<16: reveal(t)
        case ..<Cue.fullScreenIn: tabs(t)
        case ..<25: fullScreen(t)
        case ..<30: drag(t)
        case ..<33.5: peek(t)
        case ..<38: pinAndHide(t)
        case ..<Cue.stamps[0]: eject(t)
        case ..<Cue.oneMoreThing: values(t)
        case ..<Cue.finale: twist(t)
        default: finale(t)
        }
        // A white flash on the big hits.
        for hit in [Cue.press, Cue.drop, Cue.finale] {
            let flash = 1 - Motion.progress(t, hit, 0.35)
            if t >= hit, flash > 0 { canvas.fill(canvas.bounds, NSColor(white: 1, alpha: 0.55 * flash * flash)) }
        }
    }

    // MARK: - Helpers

    private var c: Canvas { canvas }

    /// A headline that rises in at `start` and fades out at `end`.
    private func headline(_ string: String, at point: CGPoint, size: CGFloat, t: Double, start: Double, end: Double,
                          gradient: Bool = false, weight: NSFont.Weight = .bold, color: NSColor = .white) {
        let appear = Motion.easeOut(Motion.progress(t, start, 0.45))
        let alpha = min(appear, 1 - Motion.easeIn(Motion.progress(t, end - 0.25, 0.25)))
        guard alpha > 0 else { return }
        let p = CGPoint(x: point.x, y: point.y + (1 - appear) * 36)
        c.group(alpha: alpha) {
            let font = Canvas.font(size, weight)
            c.ctx.saveGState()
            c.shadow(NSColor(white: 0, alpha: 0.45), blur: 30, offset: CGSize(width: 0, height: 8))
            if gradient {
                c.gradientText(string, font, center: p, colors: Canvas.accent, tracking: -size * 0.02)
            } else {
                c.text(string, font, color, at: p, tracking: -size * 0.02)
            }
            c.ctx.restoreGState()
        }
    }

    private func panelRect(_ rect: CGRect, origin: CGPoint? = nil) -> CGRect {
        let o = origin ?? panelOrigin
        return CGRect(x: o.x + rect.minX * panelScale, y: o.y + rect.minY * panelScale,
                      width: rect.width * panelScale, height: rect.height * panelScale)
    }

    private func desktop(_ t: Double) {
        c.wallpaper(t)
        c.menuBar(active: true)
    }

    /// The panel dropping out of the menu bar at `start`.
    private func panelEntrance(_ state: String, t: Double, start: Double, origin: CGPoint? = nil,
                               next: (state: String, amount: Double)? = nil) {
        let o = origin ?? panelOrigin
        let p = Motion.progress(t, start, 0.55)
        guard p > 0 else { return }
        let anchor = CGPoint(x: o.x + assets.panelSize.width * panelScale / 2, y: o.y)
        c.group(alpha: Motion.easeOut(Motion.clamp(p * 3))) {
            c.ctx.saveGState()
            c.transform(anchor: anchor, scale: 0.75 + 0.25 * Motion.spring(p, bounce: 0.9))
            c.panel(assets, state, origin: o, scale: panelScale, reveal: Motion.progress(t, start, 1.0) * 1.25, next: next)
            c.ctx.restoreGState()
        }
    }

    // MARK: - 1. Cold open: "where is it?"

    private static let chaosTypes = ["pdf", "png", "docx", "xlsx", "pptx", "zip", "mp4", "mp3", "txt", "key", "folder", "jpg", "csv", "md"]

    private func chaos(_ t: Double, blowAway: Double = 0) {
        let count = 110
        for i in 0..<count {
            let r = Motion.random(i * 7 + 1)
            let start = Cue.rainStart + 2.6 * sqrt(Double(i) / Double(count)) + r * 0.2
            let p = Motion.clamp((t - start) / 0.55)
            guard p > 0 else { continue }
            let size = 100 + Motion.random(i * 7 + 2) * 90
            let x = 60 + Motion.random(i * 7 + 3) * 1800
            let rest = 1080 - size * 0.55 - Motion.random(i * 7 + 4) * 200 - Double(i) / Double(count) * 520
            var y = Motion.lerp(-200, rest, Motion.easeIn(p))
            let landed = t - start - 0.55
            if landed > 0 { y -= 40 * exp(-7 * landed) * abs(sin(landed * 14)) }
            let spin = (Motion.random(i * 7 + 5) - 0.5) * 1.6
            var rotation = spin * (1 - p * 0.5)
            var position = CGPoint(x: x, y: y)
            var alpha = 1.0
            if blowAway > 0 {
                let angle = atan2(y - 560, x - 960)
                let distance = blowAway * blowAway * (1400 + Motion.random(i) * 900)
                position = position + CGPoint(x: cos(angle) * distance, y: sin(angle) * distance)
                rotation += blowAway * 6 * (Motion.random(i * 3) - 0.5)
                alpha = 1 - blowAway
            }
            c.group(alpha: alpha) {
                c.ctx.saveGState()
                c.transform(anchor: position, rotation: rotation)
                c.image(assets.icon(Self.chaosTypes[i % Self.chaosTypes.count]),
                        in: CGRect(x: position.x - size / 2, y: position.y - size / 2, width: size, height: size))
                c.ctx.restoreGState()
            }
        }
        // Finder windows piling up.
        let titles = ["Downloads", "Final_v2", "Desktop", "New Folder (3)", "Final_v3_REAL", "Documents", "Untitled Folder", "Final_FINAL"]
        for (i, title) in titles.enumerated() {
            let start = 4.5 + Double(i) * 0.2
            let p = Motion.progress(t, start, 0.4)
            guard p > 0 else { continue }
            let w = 420 + Motion.random(i + 90) * 160, h = 280 + Motion.random(i + 91) * 80
            var center = CGPoint(x: 260 + Motion.random(i + 92) * 1400, y: 200 + Motion.random(i + 93) * 520)
            var alpha = 1.0
            if blowAway > 0 {
                center = center + CGPoint(x: (center.x - 960) * blowAway * 3, y: (center.y - 540) * blowAway * 3)
                alpha = 1 - blowAway
            }
            c.group(alpha: alpha) {
                c.ctx.saveGState()
                c.transform(anchor: center, scale: 0.6 + 0.4 * Motion.spring(p, bounce: 1), rotation: (Motion.random(i + 94) - 0.5) * 0.12)
                let rect = CGRect(x: center.x - w / 2, y: center.y - h / 2, width: w, height: h)
                c.windowChrome(rect, title: title, dark: true, radius: 12)
                for k in 0..<6 {
                    let icon = assets.icon(Self.chaosTypes[(i + k) % Self.chaosTypes.count])
                    c.image(icon, in: CGRect(x: rect.minX + 30 + CGFloat(k % 3) * (w - 60) / 3, y: rect.minY + 80 + CGFloat(k / 3) * 100,
                                             width: 80, height: 80))
                }
                c.ctx.restoreGState()
            }
        }
    }

    private func coldOpen(_ t: Double) {
        c.stage(t)
        let texts = ["You downloaded it.", "You saved it.", "You opened it yesterday."]
        for (index, string) in texts.enumerated() {
            let start = Cue.lines[index]
            let dim = index < texts.count - 1 && t > Cue.lines[index + 1] ? 0.4 : 1
            c.group(alpha: dim) {
                headline(string, at: CGPoint(x: 960, y: 420 + CGFloat(index) * 110), size: 78, t: t, start: start, end: Cue.rainStart + 0.4,
                         weight: .semibold)
            }
        }
        chaos(t)
        // "So… where is it?" shakes over the mess.
        let p = Motion.progress(t, Cue.whereIsIt, 0.3)
        if p > 0 {
            c.glow(center: CGPoint(x: 960, y: 540), radius: 700, NSColor(white: 0, alpha: 0.75 * p))
            let shake = max(0, 1 - (t - Cue.whereIsIt) / 1.2) * 14
            let jitter = CGPoint(x: (Motion.random(Int(t * 30)) - 0.5) * shake, y: (Motion.random(Int(t * 30) + 7) - 0.5) * shake)
            c.group(alpha: Motion.easeOut(p)) {
                c.ctx.saveGState()
                c.transform(anchor: CGPoint(x: 960, y: 540), scale: 1.25 - 0.25 * Motion.easeOut(p), offset: jitter)
                c.shadow(NSColor(white: 0, alpha: 0.8), blur: 40)
                c.text("So… where is it?", Canvas.font(132, .heavy), .white, at: CGPoint(x: 960, y: 540), tracking: -3)
                c.ctx.restoreGState()
            }
        }
    }

    // MARK: - 2. The shortcut: biu biu

    private func shortcut(_ t: Double) {
        c.stage(t)
        chaos(Cue.freeze, blowAway: Motion.easeOut(Motion.progress(t, Cue.press, 0.6)))
        c.fill(c.bounds, NSColor(white: 0, alpha: 0.72 * Motion.easeOut(Motion.progress(t, Cue.freeze, 0.2))))

        let keysIn = Motion.progress(t, Cue.freeze + 0.05, 0.6)
        let keysOut = Motion.progress(t, 8.75, 0.3)
        let pressed = Motion.easeOut(Motion.progress(t, Cue.press - 0.08, 0.08)) * (1 - Motion.progress(t, 8.45, 0.12))
        let keyCenter = CGPoint(x: 960, y: 600)
        c.group(alpha: (1 - keysOut) * Motion.clamp(keysIn * 3)) {
            headline("Just press", at: CGPoint(x: 960, y: 400), size: 44, t: t, start: Cue.freeze + 0.15, end: Cue.press + 0.1, weight: .medium,
                     color: NSColor(white: 1, alpha: 0.75))
            c.ctx.saveGState()
            c.transform(anchor: keyCenter, offset: CGPoint(x: 0, y: (1 - Motion.spring(keysIn, bounce: 1)) * 300))
            c.keys(["⌥", "⌘", "R"], center: keyCenter, size: 150, pressed: pressed)
            c.ctx.restoreGState()
        }
        c.laser(from: CGPoint(x: 800, y: 560), to: Canvas.menuItemCenter, p: Motion.progress(t, Cue.press, 0.6))
        c.laser(from: CGPoint(x: 1120, y: 560), to: Canvas.menuItemCenter, p: Motion.progress(t, Cue.secondBiu, 0.6), color: Canvas.magenta)
        c.burst("biu!", center: CGPoint(x: 560, y: 360), p: Motion.progress(t, Cue.press, 0.8), rotation: -0.14, size: 95)
        c.burst("biu!", center: CGPoint(x: 1360, y: 780), p: Motion.progress(t, Cue.secondBiu, 0.8), rotation: 0.1, size: 95)

        // The desktop opens up from the menu bar item.
        let wipe = Motion.easeInOut(Motion.progress(t, 8.7, 0.9))
        if wipe > 0 {
            c.ctx.saveGState()
            let r = 2300 * wipe
            c.ctx.addEllipse(in: CGRect(x: Canvas.menuItemCenter.x - r, y: Canvas.menuItemCenter.y - r, width: r * 2, height: r * 2))
            c.ctx.clip()
            desktop(t)
            c.ctx.restoreGState()
        }
    }

    // MARK: - 3. One timeline

    private func reveal(_ t: Double) {
        desktop(t)
        c.glow(center: Canvas.menuItemCenter, radius: 160, Canvas.cyan.withAlphaComponent(0.7 * (1 - Motion.progress(t, Cue.drop, 0.5))))
        panelEntrance("all", t: t, start: Cue.drop)
        headline("Everything you touched.", at: CGPoint(x: 640, y: 400), size: 84, t: t, start: 10.6, end: 15.9)
        headline("One timeline.", at: CGPoint(x: 640, y: 505), size: 96, t: t, start: 11.1, end: 15.9, gradient: true, weight: .heavy)

        let events: [(String, String, NSColor)] = [
            ("Opened", "Homepage Draft.sketch", Canvas.cyan), ("Saved", "Quarterly Review.pptx", Canvas.magenta),
            ("Downloaded", "Product Guide v2.pdf", Canvas.amber), ("Installed", "Calculator", Canvas.cyan),
            ("Connected", "Backup", Canvas.magenta),
        ]
        for (index, event) in events.enumerated() {
            let start = 12.4 + Double(index) * 0.65
            let amount = Motion.window(t, start, start + 0.65, fade: 0.12)
            guard amount > 0 else { continue }
            c.highlight(assets.row(event.1, in: "all"), origin: panelOrigin, scale: panelScale, amount: amount, color: event.2)
            c.group(alpha: amount) {
                let font = Canvas.font(46, .semibold)
                let size = c.textSize(event.0, font)
                let pill = CGRect(x: 640 - size.width / 2 - 34, y: 640 - 40, width: size.width + 68, height: 80)
                c.fill(pill, event.2.withAlphaComponent(0.2), radius: 40)
                c.stroke(pill, event.2, radius: 40, width: 2.5)
                c.text(event.0, font, .white, at: CGPoint(x: 640, y: 640))
            }
        }
    }

    // MARK: - 4. Tabs and search

    private func tabs(_ t: Double) {
        desktop(t)
        let states = ["files", "folders", "downloads", "apps", "all"]
        var state = "all", next: (String, Double)?
        for (index, time) in Cue.tabSwitches.enumerated() where t >= time - 0.1 {
            let previous = index == 0 ? "all" : states[index - 1]
            let amount = Motion.progress(t, time - 0.1, 0.12)
            state = amount >= 1 ? states[index] : previous
            next = amount >= 1 ? nil : (states[index], amount)
        }
        for (index, time) in Cue.typing.enumerated() where t >= time - 0.06 {
            let amount = Motion.progress(t, time - 0.06, 0.08)
            let target = "search-\(index + 1)"
            state = amount >= 1 ? target : (index == 0 ? "all" : "search-\(index)")
            next = amount >= 1 ? nil : (target, amount)
        }
        c.panel(assets, state, origin: panelOrigin, scale: panelScale, next: next)

        headline("Sorted in one keystroke.", at: CGPoint(x: 640, y: 420), size: 80, t: t, start: 16.05, end: 18.85)
        let current = Cue.tabSwitches.lastIndex { t >= $0 - 0.1 }
        if let current, t < 18.9 {
            let since = t - Cue.tabSwitches[current]
            let pressed = since < 0 ? 0 : max(0, 1 - since / 0.25)
            c.group(alpha: Motion.window(t, 16.35, 18.85, fade: 0.15)) {
                c.keys(["⌘", "\(current + 2 > 5 ? 1 : current + 2)"], center: CGPoint(x: 640, y: 590), size: 110, pressed: pressed)
            }
        }
        headline("Or just start typing.", at: CGPoint(x: 640, y: 420), size: 80, t: t, start: 19.0, end: 20.95)
        let searchGlow = Motion.window(t, 19.1, 20.9, fade: 0.2)
        let field = assets.layout.searchField
        c.highlight(CGRect(x: field[0], y: field[1], width: field[2], height: field[3]), origin: panelOrigin, scale: panelScale,
                    amount: searchGlow)
        c.group(alpha: searchGlow) {
            let typed = Cue.typing.filter { t >= $0 }.count
            let word = String("inv".prefix(typed))
            let font = Canvas.font(72, .semibold, rounded: true)
            let box = c.text(word.isEmpty ? " " : word, font, Canvas.cyan, at: CGPoint(x: 640, y: 590))
            if Int(t * 2.5) % 2 == 0 { c.fill(CGRect(x: box.maxX + 6, y: 550, width: 5, height: 80), Canvas.cyan) }
        }
        c.highlight(assets.row("Invoice September.pdf", in: "search-3"), origin: panelOrigin, scale: panelScale,
                    amount: Motion.window(t, 20.0, 20.95, fade: 0.15), color: Canvas.amber)
    }

    // MARK: - 5. Over full-screen apps

    private func fullScreen(_ t: Double) {
        let slide = Motion.easeOut(Motion.progress(t, Cue.fullScreenIn, 0.45))
        if slide < 1 { desktop(t) }
        c.ctx.saveGState()
        c.transform(anchor: .zero, offset: CGPoint(x: 0, y: (1 - slide) * 1080))
        c.fullScreenEditor(t)
        c.ctx.restoreGState()
        c.glow(center: CGPoint(x: 640, y: 480), radius: 1000, NSColor(white: 0, alpha: 0.85 * Motion.progress(t, 21.4, 0.4)))

        headline("Even over full-screen apps.", at: CGPoint(x: 640, y: 400), size: 80, t: t, start: 21.5, end: 24.95)
        let keysIn = Motion.progress(t, 21.8, 0.4)
        let pressed = Motion.easeOut(Motion.progress(t, Cue.fullScreenPress - 0.06, 0.06)) * (1 - Motion.progress(t, 22.75, 0.12))
        c.group(alpha: Motion.clamp(keysIn * 2) * (1 - Motion.progress(t, 24.6, 0.3))) {
            c.keys(["⌥", "⌘", "R"], center: CGPoint(x: 640, y: 590 + (1 - Motion.spring(keysIn)) * 60), size: 105, pressed: pressed)
        }
        let origin = CGPoint(x: panelOrigin.x, y: 40)
        c.laser(from: CGPoint(x: 640, y: 560), to: CGPoint(x: origin.x + 280, y: 60), p: Motion.progress(t, Cue.fullScreenPress, 0.6))
        panelEntrance("all", t: t, start: Cue.fullScreenPress + 0.08, origin: origin)
    }

    // MARK: - 6. Drag and drop

    private func drag(_ t: Double) {
        desktop(t)
        let mail = CGRect(x: 110, y: 170, width: 1000, height: 760)
        let slide = Motion.easeOut(Motion.progress(t, 25.0, 0.45))
        let dropPoint = CGPoint(x: 520, y: 720)
        let rowRect = panelRect(assets.row("Product Guide v2.pdf", in: "all"))
        let rowCenter = CGPoint(x: rowRect.midX - 60, y: rowRect.midY)
        let dragP = Motion.easeInOut(Motion.progress(t, Cue.dragStart, Cue.drop2 - Cue.dragStart))
        let attachment = Motion.progress(t, Cue.drop2, 0.6)

        c.ctx.saveGState()
        c.transform(anchor: .zero, offset: CGPoint(x: -(1 - slide) * 1200, y: 0))
        c.mailWindow(mail, assets: assets, attachment: attachment,
                     dropHighlight: Motion.clamp((dragP - 0.6) / 0.2) * (1 - Motion.progress(t, Cue.drop2, 0.15)))
        c.ctx.restoreGState()
        c.panel(assets, "all", origin: panelOrigin, scale: panelScale)
        headline("Drag it anywhere.", at: CGPoint(x: 610, y: 100), size: 72, t: t, start: 25.2, end: 29.95)

        // Pointer: into the row, then along an arc to the message.
        let approach = Motion.easeInOut(Motion.progress(t, 25.6, 0.5))
        let control = CGPoint(x: 1050, y: 260)
        func arc(_ p: Double) -> CGPoint {
            let a = rowCenter.lerp(to: control, p), b = control.lerp(to: dropPoint, p)
            return a.lerp(to: b, p)
        }
        let pointer = t < Cue.dragStart ? CGPoint(x: 1700, y: 950).lerp(to: rowCenter, approach) : arc(dragP)
        if t >= Cue.dragStart, t < Cue.drop2 + 0.15, let ghost = assets.crop("all", assets.row("Product Guide v2.pdf", in: "all")) {
            let lift = Motion.easeOut(Motion.progress(t, Cue.dragStart, 0.15))
            let shrink = 1 - Motion.progress(t, Cue.drop2, 0.15)
            c.group(alpha: 0.85 * shrink) {
                let size = CGSize(width: rowRect.width * (1 - 0.2 * lift) * shrink, height: rowRect.height * (1 - 0.2 * lift) * shrink)
                c.ctx.saveGState()
                c.shadow(NSColor(white: 0, alpha: 0.5), blur: 30, offset: CGSize(width: 0, height: 16))
                c.fill(CGRect(x: pointer.x - size.width * 0.2, y: pointer.y - size.height / 2, width: size.width, height: size.height),
                       NSColor(white: 0.18, alpha: 1), radius: 10)
                c.ctx.restoreGState()
                c.image(ghost, in: CGRect(x: pointer.x - size.width * 0.2, y: pointer.y - size.height / 2, width: size.width, height: size.height))
            }
        }
        c.group(alpha: 1 - Motion.progress(t, 29.4, 0.4)) {
            c.pointer(at: pointer, copyBadge: Motion.progress(t, Cue.dragStart + 0.2, 0.15) * (1 - Motion.progress(t, Cue.drop2, 0.1)))
        }
    }

    // MARK: - 7. Quick Look

    private func peek(_ t: Double) {
        desktop(t)
        c.panel(assets, "all", origin: panelOrigin, scale: panelScale)
        c.fill(c.bounds, NSColor(white: 0, alpha: 0.3 * Motion.progress(t, Cue.spacePress, 0.3)))
        headline("Peek with Space.", at: CGPoint(x: 470, y: 100), size: 72, t: t, start: 30.05, end: 33.45)
        let pressed = Motion.easeOut(Motion.progress(t, Cue.spacePress - 0.06, 0.06)) * (1 - Motion.progress(t, 30.65, 0.12))
        c.group(alpha: Motion.window(t, 30.05, 33.45, fade: 0.2)) {
            c.keys(["Space"], center: CGPoint(x: 940, y: 96), size: 66, pressed: pressed)
        }
        let open = Motion.progress(t, Cue.spacePress + 0.1, 0.45)
        guard open > 0 else { return }
        let from = panelRect(assets.row("Product Guide v2.pdf", in: "all"))
        let to = CGRect(x: 240, y: 168, width: 720, height: 880)
        let s = Motion.spring(open, bounce: 0.8)
        let rect = CGRect(x: Motion.lerp(from.minX, to.minX, s), y: Motion.lerp(from.minY, to.minY, s),
                          width: Motion.lerp(from.width, to.width, s), height: Motion.lerp(from.height, to.height, s))
        c.group(alpha: Motion.clamp(open * 4)) {
            c.ctx.saveGState()
            c.ctx.translateBy(x: rect.minX, y: rect.minY)
            c.ctx.scaleBy(x: rect.width / to.width, y: rect.height / to.height)
            c.ctx.translateBy(x: -to.minX, y: -to.minY)
            c.quickLook(to)
            c.ctx.restoreGState()
        }
    }

    // MARK: - 8. Pin and ignore

    private func pinAndHide(_ t: Double) {
        desktop(t)
        let pinned = Motion.progress(t, Cue.pinPress + 0.1, 0.2)
        let ignored = Motion.progress(t, Cue.ignoreClick + 0.05, 0.25)
        if ignored > 0 {
            c.panel(assets, "pinned", origin: panelOrigin, scale: panelScale, next: ("ignored", ignored))
        } else {
            c.panel(assets, "all", origin: panelOrigin, scale: panelScale, next: ("pinned", pinned))
        }
        headline("Pin what matters.", at: CGPoint(x: 640, y: 420), size: 84, t: t, start: 33.55, end: 35.4)
        let pressed = Motion.easeOut(Motion.progress(t, Cue.pinPress - 0.06, 0.06)) * (1 - Motion.progress(t, Cue.pinPress + 0.25, 0.12))
        c.group(alpha: Motion.window(t, 33.7, 35.4, fade: 0.2)) {
            c.keys(["⌘", "P"], center: CGPoint(x: 640, y: 590), size: 110, pressed: pressed)
        }
        let pinGlow = Motion.window(t, Cue.pinPress + 0.25, 35.4, fade: 0.2)
        let pinnedRows = (assets.layout.states["pinned"] ?? []).prefix(3).dropFirst()
        for row in pinnedRows {
            c.highlight(row.rect, origin: panelOrigin, scale: panelScale, amount: pinGlow, color: Canvas.amber)
        }

        headline("Hide what doesn't.", at: CGPoint(x: 640, y: 420), size: 84, t: t, start: 35.5, end: 37.95)
        let target = panelRect(assets.row("Website Redesign", in: "pinned"))
        let pointerAt = CGPoint(x: target.midX - 40, y: target.midY)
        let approach = Motion.easeInOut(Motion.progress(t, 35.45, 0.5))
        let menuOpen = t >= Cue.rightClick && t < Cue.ignoreClick
        if t >= Cue.rightClick - 0.6, t < Cue.ignoreClick {
            c.highlight(assets.row("Website Redesign", in: "pinned"), origin: panelOrigin, scale: panelScale,
                        amount: Motion.progress(t, Cue.rightClick - 0.1, 0.1), color: .systemBlue)
        }
        if menuOpen {
            let highlighted = t > 36.35 ? 7 : nil
            c.group(alpha: Motion.progress(t, Cue.rightClick, 0.08)) {
                c.contextMenu(at: CGPoint(x: pointerAt.x - 320, y: pointerAt.y - 150), highlighted: highlighted,
                              submenu: Motion.progress(t, 36.45, 0.1), submenuHighlighted: t > 36.7 ? 1 : nil, submenuOnLeft: true)
            }
        }
        let hiddenRows = ["Homepage Draft.sketch", "Website Redesign"]
        for title in hiddenRows {
            c.highlight(assets.row(title, in: "pinned"), origin: panelOrigin, scale: panelScale,
                        amount: Motion.window(t, Cue.ignoreClick - 0.05, Cue.ignoreClick + 0.3, fade: 0.08), color: Canvas.magenta)
        }
        let menuPointer = t < Cue.rightClick + 0.3 ? pointerAt
            : t < 36.7 ? pointerAt.lerp(to: CGPoint(x: pointerAt.x - 200, y: pointerAt.y + 120), Motion.easeInOut(Motion.progress(t, 36.0, 0.35)))
            : CGPoint(x: pointerAt.x - 200, y: pointerAt.y + 120).lerp(to: CGPoint(x: pointerAt.x - 520, y: pointerAt.y + 150),
                                                                       Motion.easeInOut(Motion.progress(t, 36.5, 0.3)))
        c.group(alpha: Motion.progress(t, 35.45, 0.15) * (1 - Motion.progress(t, 37.6, 0.3))) {
            c.pointer(at: t < Cue.rightClick ? CGPoint(x: 1750, y: 980).lerp(to: pointerAt, approach) : menuPointer)
        }
    }

    // MARK: - 9. Eject

    private func eject(_ t: Double) {
        desktop(t)
        let gone = Motion.progress(t, Cue.ejectClick + 0.1, 0.25)
        c.panel(assets, "ignored", origin: panelOrigin, scale: panelScale, next: ("ejected", gone))
        headline("Eject drives right from the list.", at: CGPoint(x: 640, y: 420), size: 64, t: t, start: 38.05, end: 41.95)
        headline("No Finder trip needed.", at: CGPoint(x: 640, y: 505), size: 44, t: t, start: 39.4, end: 41.95,
                 weight: .medium, color: NSColor(white: 1, alpha: 0.7))
        let row = assets.layout.states["ignored"]?.first { $0.title == "Backup" }
        guard let row, let accessory = row.accessory else { return }
        let button = panelRect(CGRect(x: accessory[0], y: accessory[1], width: accessory[2], height: accessory[3]))
        c.highlight(row.rect, origin: panelOrigin, scale: panelScale,
                    amount: Motion.window(t, 38.4, Cue.ejectClick + 0.2, fade: 0.15), color: Canvas.amber)
        let target = CGPoint(x: button.midX, y: button.midY)
        let approach = Motion.easeInOut(Motion.progress(t, 38.2, 0.6))
        let click = Motion.window(t, Cue.ejectClick, Cue.ejectClick + 0.15, fade: 0.05)
        if click > 0 { c.fillEllipse(center: target, radius: 24 + 20 * CGFloat(click), Canvas.amber.withAlphaComponent(0.35 * click)) }
        c.group(alpha: 1 - Motion.progress(t, 40.6, 0.4)) {
            c.pointer(at: CGPoint(x: 900, y: 900).lerp(to: target, approach), scale: 1.6 * (1 - 0.1 * click))
        }
    }

    // MARK: - 10. Promises

    private func values(_ t: Double) {
        c.stage(t, glow: 1.4)
        let lines: [(String, Bool)] = [("100% local.", false), ("Powered by Spotlight.", true), ("Free & open source.", false)]
        for (index, line) in lines.enumerated() {
            let start = Cue.stamps[index]
            let p = Motion.progress(t, start, 0.2)
            guard p > 0 else { continue }
            let center = CGPoint(x: 960, y: 300 + CGFloat(index) * 150)
            c.group(alpha: Motion.easeOut(p) * (1 - Motion.progress(t, 45.7, 0.3))) {
                c.ctx.saveGState()
                c.transform(anchor: center, scale: 1.5 - 0.5 * Motion.easeOut(p))
                let font = Canvas.font(110, .heavy)
                if line.1 {
                    c.gradientText(line.0, font, center: center, colors: Canvas.accent, tracking: -3)
                } else {
                    c.text(line.0, font, .white, at: center, tracking: -3)
                }
                c.ctx.restoreGState()
            }
        }
        let hellos = ["Hello", "你好", "哈囉", "こんにちは", "안녕하세요", "Hallo", "Bonjour", "Hola", "Olá", "Привет"]
        let shown = hellos.indices.filter { t >= Cue.hellos + Double($0) * 0.1 }
        if !shown.isEmpty {
            c.group(alpha: 1 - Motion.progress(t, 45.7, 0.3)) {
                let string = shown.map { hellos[$0] }.joined(separator: "  ·  ")
                c.text(string, Canvas.font(38, .medium), NSColor(white: 1, alpha: 0.75), at: CGPoint(x: 960, y: 790))
                headline("Speaks 10 languages.", at: CGPoint(x: 960, y: 860), size: 32, t: t, start: 45.0, end: 46.0,
                         weight: .semibold, color: Canvas.cyan)
            }
        }
    }

    // MARK: - 11. One more thing

    private func twist(_ t: Double) {
        if t < Cue.twist {
            c.fill(c.bounds, .black)
            headline("One more thing…", at: CGPoint(x: 960, y: 540), size: 56, t: t, start: Cue.oneMoreThing + 0.1, end: Cue.twist - 0.05,
                     weight: .medium)
            return
        }
        let push = Motion.easeInOut(Motion.progress(t, Cue.twist, 3))
        let rowRect = panelRect(assets.row("BiuBiu Promo.mp4", in: "twist"))
        c.ctx.saveGState()
        c.transform(anchor: CGPoint(x: rowRect.midX, y: rowRect.midY), scale: 1 + 0.12 * push)
        desktop(t)
        panelEntrance("twist", t: t, start: Cue.twist)
        let pulse = 0.6 + 0.4 * sin((t - Cue.twist) * 6)
        c.highlight(assets.row("BiuBiu Promo.mp4", in: "twist"), origin: panelOrigin, scale: panelScale,
                    amount: Motion.progress(t, 47.6, 0.3) * pulse, color: Canvas.magenta)
        c.ctx.restoreGState()
        headline("This video?", at: CGPoint(x: 640, y: 420), size: 96, t: t, start: 47.7, end: 49.95, weight: .heavy)
        headline("BiuBiu already has it.", at: CGPoint(x: 640, y: 530), size: 70, t: t, start: 48.4, end: 49.95, gradient: true)
    }

    // MARK: - 12. Finale

    private func finale(_ t: Double) {
        c.stage(t, glow: 1.6)
        let iconCenter = CGPoint(x: 960, y: 390)
        c.laser(from: CGPoint(x: -100, y: 700), to: iconCenter, p: Motion.progress(t, Cue.finale - 0.15, 0.6))
        c.laser(from: CGPoint(x: 2020, y: 80), to: iconCenter, p: Motion.progress(t, Cue.finale + 0.1, 0.6), color: Canvas.magenta)
        let pop = Motion.progress(t, Cue.finale + 0.15, 0.7)
        if pop > 0 {
            let breathe = 1 + 0.025 * sin((t - Cue.finale) * 3)
            c.glow(center: iconCenter, radius: 420, Canvas.magenta.withAlphaComponent(0.35 * pop))
            c.glow(center: iconCenter, radius: 260, Canvas.cyan.withAlphaComponent(0.35 * pop))
            c.ctx.saveGState()
            c.transform(anchor: iconCenter, scale: Motion.spring(pop, bounce: 1) * breathe)
            c.shadow(NSColor(white: 0, alpha: 0.5), blur: 40, offset: CGSize(width: 0, height: 20))
            c.image(assets.appIcon, in: CGRect(x: iconCenter.x - 150, y: iconCenter.y - 150, width: 300, height: 300))
            c.ctx.restoreGState()
        }
        c.burst("biu!", center: CGPoint(x: 640, y: 300), p: Motion.progress(t, Cue.finale, 0.8), rotation: -0.16, size: 60)
        c.burst("biu!", center: CGPoint(x: 1290, y: 470), p: Motion.progress(t, Cue.finale + 0.25, 0.8), rotation: 0.12, size: 60)
        let end = Cue.duration - 0.5
        headline("BiuBiu", at: CGPoint(x: 960, y: 640), size: 130, t: t, start: 50.5, end: end + 0.5, gradient: true, weight: .heavy)
        headline("Every recent file, one shortcut away.", at: CGPoint(x: 960, y: 745), size: 44, t: t, start: 50.9, end: end + 0.5,
                 weight: .medium)
        headline("Free  ·  Open source  ·  macOS 14+", at: CGPoint(x: 960, y: 820), size: 30, t: t, start: 51.3, end: end + 0.5,
                 weight: .regular, color: NSColor(white: 1, alpha: 0.6))
        headline("github.com/huangxinping/BiuBiu", at: CGPoint(x: 960, y: 885), size: 32, t: t, start: 51.7, end: end + 0.5,
                 weight: .semibold, color: Canvas.cyan)
        c.fill(c.bounds, NSColor(white: 0, alpha: Motion.progress(t, end - 0.2, 0.7)))
    }
}
