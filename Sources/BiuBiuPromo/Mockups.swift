import AppKit

/// Everything around the real panel: wallpaper, menu bar, keys, cursor and the made-up apps the panel works with.
@MainActor
extension Canvas {
    // MARK: - Palette

    static let ink = NSColor(srgbRed: 0.035, green: 0.035, blue: 0.07, alpha: 1)
    static let cyan = NSColor(srgbRed: 0.35, green: 0.92, blue: 1, alpha: 1)
    static let magenta = NSColor(srgbRed: 1, green: 0.33, blue: 0.72, alpha: 1)
    static let amber = NSColor(srgbRed: 1, green: 0.72, blue: 0.25, alpha: 1)
    static let accent = [cyan, NSColor(srgbRed: 0.55, green: 0.55, blue: 1, alpha: 1), magenta]

    // MARK: - Backgrounds

    /// A dark stage with a slowly breathing glow.
    func stage(_ t: Double, glow strength: CGFloat = 1) {
        fill(bounds, Self.ink)
        group(alpha: strength) {
            let drift = CGFloat(sin(t * 0.6)) * 80
            glow(center: CGPoint(x: 560 + drift, y: 380), radius: 900, NSColor(srgbRed: 0.25, green: 0.12, blue: 0.55, alpha: 0.55))
            glow(center: CGPoint(x: 1450 - drift, y: 760), radius: 800, NSColor(srgbRed: 0.05, green: 0.3, blue: 0.5, alpha: 0.45))
        }
    }

    /// A macOS-like abstract wallpaper whose color blobs drift.
    func wallpaper(_ t: Double) {
        linearGradient(bounds, [NSColor(srgbRed: 0.07, green: 0.06, blue: 0.2, alpha: 1),
                                NSColor(srgbRed: 0.2, green: 0.08, blue: 0.36, alpha: 1)],
                       from: CGPoint(x: 0, y: 0), to: CGPoint(x: 1920, y: 1080))
        let s = CGFloat(t)
        glow(center: CGPoint(x: 300 + sin(s * 0.4) * 120, y: 900 + cos(s * 0.3) * 60), radius: 900,
             NSColor(srgbRed: 0.95, green: 0.25, blue: 0.55, alpha: 0.6))
        glow(center: CGPoint(x: 1600 + cos(s * 0.35) * 140, y: 1000), radius: 800,
             NSColor(srgbRed: 1, green: 0.55, blue: 0.2, alpha: 0.5))
        glow(center: CGPoint(x: 1200 + sin(s * 0.5) * 160, y: 120), radius: 760,
             NSColor(srgbRed: 0.2, green: 0.6, blue: 1, alpha: 0.45))
    }

    static let menuBarHeight: CGFloat = 34
    /// Where the BiuBiu menu bar item sits.
    static let menuItemCenter = CGPoint(x: 1560, y: 17)

    func menuBar(active: Bool) {
        let bar = CGRect(x: 0, y: 0, width: 1920, height: Self.menuBarHeight)
        fill(bar, NSColor(white: 0, alpha: 0.35))
        let font = Canvas.font(17, .regular)
        symbol("apple.logo", at: CGPoint(x: 34, y: 17), size: 19, color: .white)
        var x: CGFloat = 70
        for (index, title) in ["Finder", "File", "Edit", "View", "Go", "Window", "Help"].enumerated() {
            let frame = text(title, index == 0 ? Canvas.font(17, .bold) : font, .white, at: CGPoint(x: x, y: 17),
                             anchor: CGPoint(x: 0, y: 0.5))
            x = frame.maxX + 24
        }
        text("Fri 9:41 AM", font, .white, at: CGPoint(x: 1896, y: 17), anchor: CGPoint(x: 1, y: 0.5))
        symbol("magnifyingglass", at: CGPoint(x: 1752, y: 17), size: 17, color: .white)
        symbol("wifi", at: CGPoint(x: 1700, y: 17), size: 17, color: .white)
        symbol("battery.100percent", at: CGPoint(x: 1640, y: 17), size: 17, color: .white)
        if active {
            fill(CGRect(x: Self.menuItemCenter.x - 20, y: 3, width: 40, height: 28), NSColor(white: 1, alpha: 0.25), radius: 7)
        }
        symbol("clock.arrow.circlepath", at: Self.menuItemCenter, size: 18, color: .white)
    }

    func symbol(_ name: String, at center: CGPoint, size: CGFloat, color: NSColor, weight: NSFont.Weight = .medium) {
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: size, weight: weight).applying(.init(paletteColors: [color])))
        else { return }
        image.draw(in: CGRect(x: center.x - image.size.width / 2, y: center.y - image.size.height / 2,
                              width: image.size.width, height: image.size.height),
                   from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    }

    // MARK: - The panel

    /// The real panel sprite at `origin` (top-left) and `scale` video pixels per panel point. `reveal` < 1
    /// builds it row by row; `next` cross-fades to another state.
    func panel(_ assets: Assets, _ state: String, origin: CGPoint, scale: CGFloat, reveal: Double = 1,
               next: (state: String, amount: Double)? = nil) {
        let size = CGSize(width: assets.panelSize.width * scale, height: assets.panelSize.height * scale)
        let frame = CGRect(origin: origin, size: size)
        ctx.saveGState()
        shadow(NSColor(white: 0, alpha: 0.55), blur: 50, offset: CGSize(width: 0, height: 24))
        fill(frame.insetBy(dx: 4, dy: 4), NSColor(white: 0, alpha: 0.9), radius: 12 * scale)
        ctx.restoreGState()
        if reveal >= 1 {
            image(assets.sprite(state), in: frame)
        } else {
            fill(frame, NSColor(white: 0.13, alpha: 1), radius: 12 * scale)
            let rows = assets.layout.states[state] ?? []
            let top = rows.first?.rect.minY ?? 60
            let footerTop = assets.panelSize.height - 36
            if let strip = assets.strip(state, y: 0, height: top) {
                group(alpha: Motion.easeOut(Motion.clamp(reveal * 4))) {
                    image(strip, in: CGRect(x: frame.minX, y: frame.minY, width: size.width, height: top * scale))
                }
            }
            for (index, row) in rows.enumerated() where row.rect.maxY <= footerTop {
                let p = Motion.easeOut(Motion.clamp(reveal * 1.6 - Double(index) * 0.07))
                guard let strip = assets.strip(state, y: row.rect.minY, height: row.rect.height) else { continue }
                group(alpha: p) {
                    image(strip, in: CGRect(x: frame.minX, y: frame.minY + (row.rect.minY + (1 - p) * 26) * scale,
                                            width: size.width, height: row.rect.height * scale))
                }
            }
            if let strip = assets.strip(state, y: footerTop, height: 36) {
                group(alpha: Motion.clamp(reveal * 2 - 1)) {
                    image(strip, in: CGRect(x: frame.minX, y: frame.minY + footerTop * scale, width: size.width, height: 36 * scale))
                }
            }
        }
        if let next, next.amount > 0 {
            group(alpha: next.amount) { image(assets.sprite(next.state), in: frame) }
        }
    }

    /// A glowing outline around a panel rectangle (in panel points).
    func highlight(_ rect: CGRect, origin: CGPoint, scale: CGFloat, amount: Double, color: NSColor = Canvas.cyan) {
        guard amount > 0 else { return }
        let r = CGRect(x: origin.x + rect.minX * scale, y: origin.y + rect.minY * scale,
                       width: rect.width * scale, height: rect.height * scale).insetBy(dx: -3, dy: -1)
        group(alpha: amount) {
            ctx.saveGState()
            shadow(color, blur: 22)
            stroke(r, color, radius: 10, width: 3)
            ctx.restoreGState()
        }
    }

    // MARK: - Keys and pointer

    /// Keyboard keys in a row, centered on `center`. `pressed` (0...1) pushes them down and lights them up.
    func keys(_ labels: [String], center: CGPoint, size: CGFloat = 130, pressed: Double, glowColor: NSColor = Canvas.cyan) {
        let gap = size * 0.18
        let widths = labels.map { $0.count > 1 ? size * 2.4 : size }
        let total = widths.reduce(0, +) + gap * CGFloat(labels.count - 1)
        var x = center.x - total / 2
        let depth = size * 0.09
        let press = CGFloat(pressed)
        for (label, width) in zip(labels, widths) {
            let base = CGRect(x: x, y: center.y - size / 2 + depth, width: width, height: size)
            let face = base.offsetBy(dx: 0, dy: -depth * (1 - press))
            ctx.saveGState()
            shadow(NSColor(white: 0, alpha: 0.6), blur: 30 * (1 - press * 0.6), offset: CGSize(width: 0, height: 16 * (1 - press)))
            fill(base, NSColor(white: 0.07, alpha: 1), radius: size * 0.2)
            ctx.restoreGState()
            if press > 0 {
                ctx.saveGState()
                shadow(glowColor.withAlphaComponent(press), blur: 60 * press)
                fill(face, glowColor.withAlphaComponent(0.35 * press), radius: size * 0.2)
                ctx.restoreGState()
            }
            linearGradient(face, [NSColor(white: 0.25, alpha: 1), NSColor(white: 0.13, alpha: 1)],
                           from: CGPoint(x: face.midX, y: face.minY), to: CGPoint(x: face.midX, y: face.maxY), radius: size * 0.2)
            stroke(face.insetBy(dx: 1, dy: 1), NSColor(white: 1, alpha: 0.12), radius: size * 0.19, width: 2)
            let glyphColor = NSColor.white.blended(withFraction: press, of: glowColor) ?? .white
            text(label, Canvas.font(label.count > 1 ? size * 0.3 : size * 0.42, .medium), glyphColor,
                 at: CGPoint(x: face.midX, y: face.midY))
            x += width + gap
        }
    }

    /// The macOS arrow pointer with its tip at `point`; `copyBadge` adds the green "+" shown while dragging.
    func pointer(at point: CGPoint, scale: CGFloat = 1.6, copyBadge: Double = 0) {
        let path = CGMutablePath()
        let pts: [CGPoint] = [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 23), CGPoint(x: 5.5, y: 17.5), CGPoint(x: 9.5, y: 26.5),
                              CGPoint(x: 13, y: 25), CGPoint(x: 9.2, y: 16.3), CGPoint(x: 16.5, y: 16.3)]
        path.addLines(between: pts.map { CGPoint(x: point.x + $0.x * scale, y: point.y + $0.y * scale) })
        path.closeSubpath()
        ctx.saveGState()
        shadow(NSColor(white: 0, alpha: 0.4), blur: 6, offset: CGSize(width: 0, height: 3))
        strokePath(path, .white, width: 2.4 * scale)
        ctx.restoreGState()
        fillPath(path, .black)
        if copyBadge > 0 {
            let c = CGPoint(x: point.x + 22 * scale, y: point.y + 28 * scale)
            group(alpha: copyBadge) {
                fillEllipse(center: c, radius: 9 * scale, .white)
                fillEllipse(center: c, radius: 7.5 * scale, NSColor.systemGreen)
                text("+", Canvas.font(14 * scale, .bold), .white, at: CGPoint(x: c.x, y: c.y - 1))
            }
        }
    }

    // MARK: - Effects

    /// A laser bolt from `from` to `to`: it shoots out over the first 30% of `p`, then fades.
    func laser(from: CGPoint, to: CGPoint, p: Double, color: NSColor = Canvas.cyan) {
        guard p > 0, p < 1 else { return }
        let head = Motion.easeOut(Motion.clamp(p / 0.3))
        let tail = Motion.easeIn(Motion.clamp((p - 0.2) / 0.8))
        let a = from.lerp(to: to, tail * 0.9), b = from.lerp(to: to, head)
        let path = CGMutablePath()
        path.move(to: a)
        path.addLine(to: b)
        let fade = 1 - Motion.clamp((p - 0.5) / 0.5)
        group(alpha: fade) {
            ctx.saveGState()
            shadow(color, blur: 40)
            strokePath(path, color.withAlphaComponent(0.5), width: 26)
            ctx.restoreGState()
            strokePath(path, color, width: 10)
            strokePath(path, .white, width: 4)
            glow(center: b, radius: 90, color.withAlphaComponent(0.8))
        }
        if head >= 1 {
            let ring = Motion.clamp((p - 0.3) / 0.5)
            group(alpha: 1 - ring) {
                ctx.saveGState()
                shadow(color, blur: 20)
                ctx.setStrokeColor(NSColor.white.cgColor)
                ctx.setLineWidth(4)
                let r = 20 + ring * 140
                ctx.strokeEllipse(in: CGRect(x: to.x - r, y: to.y - r, width: r * 2, height: r * 2))
                ctx.restoreGState()
            }
        }
    }

    /// A comic-book "biu!" burst.
    func burst(_ word: String, center: CGPoint, p: Double, rotation: CGFloat = -0.12, size: CGFloat = 120) {
        guard p > 0 else { return }
        let scale = Motion.spring(Motion.clamp(p / 0.5), bounce: 1.1)
        let fade = 1 - Motion.clamp((p - 0.75) / 0.25)
        group(alpha: fade) {
            ctx.saveGState()
            transform(anchor: center, scale: scale, rotation: rotation)
            let star = CGMutablePath()
            let spikes = 14
            for i in 0..<(spikes * 2) {
                let angle = Double(i) / Double(spikes * 2) * .pi * 2
                let r = (i % 2 == 0 ? size * 1.7 : size * 1.15) * (0.92 + Motion.random(i) * 0.16)
                let point = CGPoint(x: center.x + cos(angle) * r * 1.25, y: center.y + sin(angle) * r)
                if i == 0 { star.move(to: point) } else { star.addLine(to: point) }
            }
            star.closeSubpath()
            ctx.saveGState()
            shadow(Canvas.amber, blur: 50)
            fillPath(star, Canvas.amber)
            ctx.restoreGState()
            strokePath(star, NSColor(srgbRed: 0.2, green: 0.05, blue: 0.1, alpha: 1), width: 8)
            let font = Canvas.font(size * 1.05, .black, rounded: true)
            let path = textPath(word, font, center: center)
            strokePath(path, NSColor(srgbRed: 0.2, green: 0.05, blue: 0.1, alpha: 1), width: 16)
            gradientText(word, font, center: center, colors: [.white, NSColor(srgbRed: 1, green: 0.95, blue: 0.75, alpha: 1)])
            ctx.restoreGState()
        }
    }

    // MARK: - Windows

    func windowChrome(_ rect: CGRect, title: String, dark: Bool, radius: CGFloat = 14) {
        ctx.saveGState()
        shadow(NSColor(white: 0, alpha: 0.5), blur: 60, offset: CGSize(width: 0, height: 30))
        fill(rect, dark ? NSColor(white: 0.12, alpha: 1) : NSColor(white: 0.98, alpha: 1), radius: radius)
        ctx.restoreGState()
        let bar = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 56)
        ctx.saveGState()
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
        ctx.clip()
        fill(bar, dark ? NSColor(white: 0.17, alpha: 1) : NSColor(white: 0.93, alpha: 1))
        fill(CGRect(x: rect.minX, y: bar.maxY - 1, width: rect.width, height: 1), NSColor(white: dark ? 0 : 0.8, alpha: 1))
        ctx.restoreGState()
        for (index, color) in [NSColor.systemRed, .systemYellow, .systemGreen].enumerated() {
            fillEllipse(center: CGPoint(x: rect.minX + 26 + CGFloat(index) * 24, y: bar.midY), radius: 7.5, color)
        }
        text(title, Canvas.font(17, .semibold), dark ? .white : NSColor(white: 0.15, alpha: 1), at: CGPoint(x: rect.midX, y: bar.midY))
    }

    /// A full-screen video editor, the kind of app people get lost in.
    func fullScreenEditor(_ t: Double) {
        fill(bounds, NSColor(white: 0.09, alpha: 1))
        // Toolbar.
        fill(CGRect(x: 0, y: 0, width: 1920, height: 64), NSColor(white: 0.14, alpha: 1))
        text("Summer Trip — Edit", Canvas.font(18, .semibold), NSColor(white: 0.9, alpha: 1), at: CGPoint(x: 960, y: 32))
        for (index, name) in ["scissors", "wand.and.stars", "slider.horizontal.3", "square.and.arrow.up"].enumerated() {
            symbol(name, at: CGPoint(x: 1700 + CGFloat(index) * 56, y: 32), size: 20, color: NSColor(white: 0.75, alpha: 1))
        }
        // Media browser.
        for row in 0..<4 {
            for column in 0..<2 {
                let r = CGRect(x: 30 + CGFloat(column) * 190, y: 100 + CGFloat(row) * 140, width: 170, height: 100)
                let hue = CGFloat(Motion.random(row * 2 + column))
                linearGradient(r, [NSColor(hue: hue, saturation: 0.6, brightness: 0.8, alpha: 1),
                                   NSColor(hue: hue + 0.1, saturation: 0.7, brightness: 0.45, alpha: 1)],
                               from: CGPoint(x: r.minX, y: r.minY), to: CGPoint(x: r.maxX, y: r.maxY), radius: 8)
            }
        }
        // Viewer: a sunset that slowly moves.
        let viewer = CGRect(x: 460, y: 96, width: 1000, height: 562)
        linearGradient(viewer, [NSColor(srgbRed: 0.98, green: 0.55, blue: 0.3, alpha: 1),
                                NSColor(srgbRed: 0.55, green: 0.2, blue: 0.5, alpha: 1)],
                       from: CGPoint(x: viewer.midX, y: viewer.maxY), to: CGPoint(x: viewer.midX, y: viewer.minY), radius: 6)
        ctx.saveGState()
        ctx.clip(to: viewer)
        let sunY = viewer.minY + 330 + CGFloat(sin(t * 0.8)) * 16
        glow(center: CGPoint(x: viewer.midX + 120, y: sunY), radius: 260, NSColor(srgbRed: 1, green: 0.9, blue: 0.6, alpha: 0.9))
        fillEllipse(center: CGPoint(x: viewer.midX + 120, y: sunY), radius: 70, NSColor(srgbRed: 1, green: 0.95, blue: 0.8, alpha: 1))
        for (layer, color) in [(0, NSColor(srgbRed: 0.35, green: 0.12, blue: 0.35, alpha: 1)),
                               (1, NSColor(srgbRed: 0.18, green: 0.06, blue: 0.2, alpha: 1))] {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: viewer.minX, y: viewer.maxY))
            let shift = CGFloat(t) * (layer == 0 ? 6 : 14)
            for i in 0...20 {
                let x = viewer.minX + CGFloat(i) * 50
                let y = viewer.maxY - 140 + CGFloat(layer) * 60 - CGFloat(sin(Double(x + shift) / 90 + Double(layer) * 2)) * 60
                path.addLine(to: CGPoint(x: x, y: y))
            }
            path.addLine(to: CGPoint(x: viewer.maxX, y: viewer.maxY))
            path.closeSubpath()
            fillPath(path, color)
        }
        ctx.restoreGState()
        // Timeline.
        fill(CGRect(x: 0, y: 700, width: 1920, height: 380), NSColor(white: 0.12, alpha: 1))
        let clipColors: [NSColor] = [.systemBlue, .systemPurple, .systemTeal, .systemIndigo, .systemPink]
        for track in 0..<4 {
            var x: CGFloat = 40 + CGFloat(Motion.random(track + 40) * 80)
            var index = 0
            while x < 1880 {
                let w = 160 + CGFloat(Motion.random(track * 31 + index) * 320)
                let r = CGRect(x: x, y: 740 + CGFloat(track) * 76, width: min(w, 1880 - x), height: 60)
                fill(r, clipColors[(track + index) % clipColors.count].withAlphaComponent(0.75), radius: 8)
                x += w + 8
                index += 1
            }
        }
        let playhead = 300 + CGFloat(t.truncatingRemainder(dividingBy: 30)) * 40
        fill(CGRect(x: playhead, y: 712, width: 3, height: 360), .systemRed)
    }

    /// A new-message window; `attachment` (0...1) drops the guide in.
    func mailWindow(_ rect: CGRect, assets: Assets, attachment: Double, dropHighlight: Double) {
        windowChrome(rect, title: "New Message", dark: false)
        let left = rect.minX + 36
        let dark = NSColor(white: 0.15, alpha: 1), gray = NSColor(white: 0.55, alpha: 1)
        let font = Canvas.font(20)
        var y = rect.minY + 96
        for (label, value) in [("To:", "team@example.com"), ("Subject:", "Product guide for Friday")] {
            let l = text(label, font, gray, at: CGPoint(x: left, y: y), anchor: CGPoint(x: 0, y: 0.5))
            text(value, font, dark, at: CGPoint(x: l.maxX + 12, y: y), anchor: CGPoint(x: 0, y: 0.5))
            fill(CGRect(x: left, y: y + 24, width: rect.width - 72, height: 1), NSColor(white: 0.85, alpha: 1))
            y += 56
        }
        y += 16
        for line in ["Hi team,", "", "Here's the latest guide for Friday's launch.", "", "Thanks!"] {
            if !line.isEmpty { text(line, font, dark, at: CGPoint(x: left, y: y), anchor: CGPoint(x: 0, y: 0.5)) }
            y += 34
        }
        if dropHighlight > 0 {
            let zone = CGRect(x: left - 12, y: rect.minY + 220, width: rect.width - 48, height: rect.height - 250)
            group(alpha: dropHighlight) {
                stroke(zone, NSColor.systemBlue, radius: 12, width: 3)
                fill(zone, NSColor.systemBlue.withAlphaComponent(0.06), radius: 12)
            }
        }
        if attachment > 0 {
            let chip = CGRect(x: left, y: y + 20, width: 400, height: 92)
            let scale = Motion.spring(attachment, bounce: 1.2)
            ctx.saveGState()
            transform(anchor: CGPoint(x: chip.midX, y: chip.midY), scale: scale)
            fill(chip, NSColor(white: 0.94, alpha: 1), radius: 14)
            stroke(chip, NSColor(white: 0.82, alpha: 1), radius: 14, width: 1.5)
            image(assets.icon("pdf"), in: CGRect(x: chip.minX + 14, y: chip.minY + 10, width: 72, height: 72))
            text("Product Guide v2.pdf", Canvas.font(20, .semibold), dark, at: CGPoint(x: chip.minX + 100, y: chip.minY + 34),
                 anchor: CGPoint(x: 0, y: 0.5))
            text("2.4 MB", Canvas.font(17), gray, at: CGPoint(x: chip.minX + 100, y: chip.minY + 62), anchor: CGPoint(x: 0, y: 0.5))
            ctx.restoreGState()
        }
    }

    /// A Quick Look window showing a made-up product guide.
    func quickLook(_ rect: CGRect) {
        windowChrome(rect, title: "Product Guide v2.pdf", dark: true)
        let page = CGRect(x: rect.minX + 40, y: rect.minY + 86, width: rect.width - 80, height: rect.height - 116)
        fill(page, .white, radius: 4)
        let left = page.minX + 50
        text("Product Guide", Canvas.font(46, .bold), NSColor(white: 0.1, alpha: 1), at: CGPoint(x: left, y: page.minY + 70),
             anchor: CGPoint(x: 0, y: 0.5))
        text("Version 2 · Autumn launch", Canvas.font(20), NSColor(white: 0.5, alpha: 1), at: CGPoint(x: left, y: page.minY + 118),
             anchor: CGPoint(x: 0, y: 0.5))
        let hero = CGRect(x: left, y: page.minY + 150, width: page.width - 100, height: 190)
        linearGradient(hero, Canvas.accent, from: CGPoint(x: hero.minX, y: hero.minY), to: CGPoint(x: hero.maxX, y: hero.maxY), radius: 12)
        let heights: [CGFloat] = [0.35, 0.55, 0.45, 0.75, 0.62, 0.9]
        for (index, h) in heights.enumerated() {
            let w: CGFloat = 46
            let x = left + CGFloat(index) * (w + 22)
            let bar = CGRect(x: x, y: page.minY + 520 - 150 * h, width: w, height: 150 * h)
            fill(bar, Canvas.accent[index % 3].withAlphaComponent(0.85), radius: 6)
        }
        // Body text, as many lines as fit the page.
        var y = page.minY + 556
        var index = 0
        while y + 12 < page.maxY - 30 {
            let w = (page.width - 100) * CGFloat(index % 3 == 2 ? 0.6 : 0.95)
            fill(CGRect(x: left, y: y, width: w, height: 12), NSColor(white: 0.88, alpha: 1), radius: 6)
            y += 30
            index += 1
        }
    }

    /// A context menu with `highlighted` item lit, and the Ignore submenu once `submenu` > 0.
    func contextMenu(at origin: CGPoint, highlighted: Int?, submenu: Double, submenuHighlighted: Int?, submenuOnLeft: Bool = false) {
        let items = ["Open", "Show in Finder", "Open With", "Quick Look", "Copy Path", "-", "Pin", "Ignore"]
        let width: CGFloat = 300, itemHeight: CGFloat = 38
        func drawMenu(_ items: [String], at origin: CGPoint, highlighted: Int?, width: CGFloat) -> [CGRect] {
            let height = items.reduce(CGFloat(16)) { $0 + ($1 == "-" ? 14 : itemHeight) }
            let rect = CGRect(x: origin.x, y: origin.y, width: width, height: height)
            ctx.saveGState()
            shadow(NSColor(white: 0, alpha: 0.5), blur: 30, offset: CGSize(width: 0, height: 14))
            fill(rect, NSColor(white: 0.17, alpha: 0.98), radius: 12)
            ctx.restoreGState()
            stroke(rect, NSColor(white: 1, alpha: 0.12), radius: 12, width: 1.5)
            var y = rect.minY + 8
            var frames: [CGRect] = []
            for (index, item) in items.enumerated() {
                if item == "-" {
                    fill(CGRect(x: rect.minX + 14, y: y + 6, width: width - 28, height: 1.5), NSColor(white: 1, alpha: 0.15))
                    y += 14
                    frames.append(.zero)
                    continue
                }
                let r = CGRect(x: rect.minX + 6, y: y, width: width - 12, height: itemHeight)
                if index == highlighted { fill(r, NSColor.systemBlue, radius: 7) }
                text(item, Canvas.font(19), .white, at: CGPoint(x: r.minX + 16, y: r.midY), anchor: CGPoint(x: 0, y: 0.5))
                if item == "Open With" || item == "Ignore" {
                    symbol("chevron.right", at: CGPoint(x: r.maxX - 18, y: r.midY), size: 13, color: NSColor(white: 1, alpha: 0.7))
                }
                frames.append(r)
                y += itemHeight
            }
            return frames
        }
        let frames = drawMenu(items, at: origin, highlighted: highlighted, width: width)
        if submenu > 0, let ignore = frames.last {
            group(alpha: submenu) {
                _ = drawMenu(["This Folder", "Everything in “Projects”"],
                             at: CGPoint(x: submenuOnLeft ? ignore.minX - 16 - 320 : ignore.maxX + 10, y: ignore.minY - 8),
                             highlighted: submenuHighlighted, width: 320)
            }
        }
    }
}
