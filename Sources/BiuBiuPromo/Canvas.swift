import AppKit
import CoreText

/// A 1920×1080 drawing surface with a top-left origin, nested opacity and a few motion-graphics helpers.
@MainActor
final class Canvas {
    let width: Int
    let height: Int
    let ctx: CGContext
    private var alphaStack: [CGFloat] = [1]

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: 1, y: -1)
        ctx.interpolationQuality = .high
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
    }

    var bounds: CGRect { CGRect(x: 0, y: 0, width: width, height: height) }

    /// BGRA pixels, as ffmpeg's `-pix_fmt bgra` expects.
    var pixels: Data { Data(bytes: ctx.data!, count: width * height * 4) }

    // MARK: - State

    /// Draws `body` with extra opacity and an optional transform, restoring both afterwards.
    func group(alpha: CGFloat = 1, _ body: () -> Void) {
        guard alpha > 0.001 else { return }
        ctx.saveGState()
        alphaStack.append(alphaStack.last! * min(alpha, 1))
        ctx.setAlpha(alphaStack.last!)
        body()
        alphaStack.removeLast()
        ctx.setAlpha(alphaStack.last!)
        ctx.restoreGState()
    }

    /// Scales and rotates around `anchor`, then moves by `offset`.
    func transform(anchor: CGPoint, scale: CGFloat = 1, scaleY: CGFloat? = nil, rotation: CGFloat = 0,
                   offset: CGPoint = .zero) {
        ctx.translateBy(x: anchor.x + offset.x, y: anchor.y + offset.y)
        if rotation != 0 { ctx.rotate(by: rotation) }
        ctx.scaleBy(x: scale, y: scaleY ?? scale)
        ctx.translateBy(x: -anchor.x, y: -anchor.y)
    }

    func shadow(_ color: NSColor, blur: CGFloat, offset: CGSize = .zero) {
        // CGContext offsets are in the unflipped device space.
        ctx.setShadow(offset: CGSize(width: offset.width, height: -offset.height), blur: blur, color: color.cgColor)
    }

    // MARK: - Shapes

    func fill(_ rect: CGRect, _ color: NSColor, radius: CGFloat = 0) {
        ctx.setFillColor(color.cgColor)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: min(radius, rect.width / 2), cornerHeight: min(radius, rect.height / 2), transform: nil))
        ctx.fillPath()
    }

    func stroke(_ rect: CGRect, _ color: NSColor, radius: CGFloat = 0, width: CGFloat = 1) {
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(width)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: min(radius, rect.width / 2), cornerHeight: min(radius, rect.height / 2), transform: nil))
        ctx.strokePath()
    }

    func fillEllipse(center: CGPoint, radius: CGFloat, _ color: NSColor) {
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    func linearGradient(_ rect: CGRect, _ colors: [NSColor], from: CGPoint, to: CGPoint, radius: CGFloat = 0) {
        ctx.saveGState()
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
        ctx.clip()
        ctx.drawLinearGradient(gradient(colors), start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        ctx.restoreGState()
    }

    /// A soft glow: the color fades to clear at `radius`.
    func glow(center: CGPoint, radius: CGFloat, _ color: NSColor) {
        ctx.drawRadialGradient(gradient([color, color.withAlphaComponent(0)]), startCenter: center, startRadius: 0,
                               endCenter: center, endRadius: radius, options: [])
    }

    func gradient(_ colors: [NSColor]) -> CGGradient {
        CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors.map(\.cgColor) as CFArray, locations: nil)!
    }

    // MARK: - Images

    func image(_ image: CGImage, in rect: CGRect) {
        ctx.saveGState()
        ctx.translateBy(x: rect.minX, y: rect.maxY)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(image, in: CGRect(origin: .zero, size: rect.size))
        ctx.restoreGState()
    }

    // MARK: - Text

    static func font(_ size: CGFloat, _ weight: NSFont.Weight = .regular, rounded: Bool = false) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: weight)
        guard rounded, let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return NSFont(descriptor: descriptor, size: size) ?? base
    }

    func textSize(_ string: String, _ font: NSFont, tracking: CGFloat = 0) -> CGSize {
        NSAttributedString(string: string, attributes: [.font: font, .kern: tracking]).size()
    }

    /// Draws a line of text; `anchor` picks which point of the text box lands on `point` (0.5,0.5 = center).
    @discardableResult
    func text(_ string: String, _ font: NSFont, _ color: NSColor, at point: CGPoint, anchor: CGPoint = CGPoint(x: 0.5, y: 0.5),
              tracking: CGFloat = 0) -> CGRect {
        let attributed = NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color, .kern: tracking])
        let size = attributed.size()
        let origin = CGPoint(x: point.x - size.width * anchor.x, y: point.y - size.height * anchor.y)
        attributed.draw(at: origin)
        return CGRect(origin: origin, size: size)
    }

    /// The outline of a line of text, its box centered on `point`, for gradient fills and strokes.
    func textPath(_ string: String, _ font: NSFont, center point: CGPoint, tracking: CGFloat = 0) -> CGPath {
        let attributed = NSAttributedString(string: string, attributes: [.font: font, .kern: tracking])
        let line = CTLineCreateWithAttributedString(attributed)
        let bounds = CTLineGetBoundsWithOptions(line, [])
        let path = CGMutablePath()
        for run in CTLineGetGlyphRuns(line) as! [CTRun] {
            let attributes = CTRunGetAttributes(run) as NSDictionary
            let runFont = attributes[kCTFontAttributeName] as! CTFont
            let count = CTRunGetGlyphCount(run)
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
            for index in 0..<count {
                guard let glyph = CTFontCreatePathForGlyph(runFont, glyphs[index], nil) else { continue }
                // Glyph paths point up; flip them into the top-left canvas.
                let transform = CGAffineTransform(translationX: point.x - bounds.midX + positions[index].x,
                                                  y: point.y + bounds.midY - positions[index].y).scaledBy(x: 1, y: -1)
                path.addPath(glyph, transform: transform)
            }
        }
        return path
    }

    /// Big title text filled with a gradient running left to right across the text.
    func gradientText(_ string: String, _ font: NSFont, center: CGPoint, colors: [NSColor], tracking: CGFloat = 0) {
        let path = textPath(string, font, center: center, tracking: tracking)
        let box = path.boundingBoxOfPath
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        ctx.drawLinearGradient(gradient(colors), start: CGPoint(x: box.minX, y: box.midY), end: CGPoint(x: box.maxX, y: box.midY),
                               options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        ctx.restoreGState()
    }

    func fillPath(_ path: CGPath, _ color: NSColor) {
        ctx.setFillColor(color.cgColor)
        ctx.addPath(path)
        ctx.fillPath()
    }

    func strokePath(_ path: CGPath, _ color: NSColor, width: CGFloat, cap: CGLineCap = .round) {
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(width)
        ctx.setLineCap(cap)
        ctx.setLineJoin(.round)
        ctx.addPath(path)
        ctx.strokePath()
    }
}
