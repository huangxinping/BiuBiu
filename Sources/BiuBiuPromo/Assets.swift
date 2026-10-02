import AppKit
import UniformTypeIdentifiers

/// The panel sprites from `BiuBiu --promo-sprites`, plus file icons and the app icon.
@MainActor
final class Assets {
    struct Layout: Decodable {
        struct Row: Decodable {
            let title: String
            let frame: [CGFloat]
            let accessory: [CGFloat]?
            var rect: CGRect { CGRect(x: frame[0], y: frame[1], width: frame[2], height: frame[3]) }
        }
        let size: [CGFloat]
        let hotKey: String
        let searchField: [CGFloat]
        let segments: [CGFloat]
        let states: [String: [Row]]
    }

    let layout: Layout
    private var sprites: [String: CGImage] = [:]
    private var icons: [String: CGImage] = [:]
    let appIcon: CGImage

    var panelSize: CGSize { CGSize(width: layout.size[0], height: layout.size[1]) }

    init(spritesDirectory: URL, appIconURL: URL) throws {
        layout = try JSONDecoder().decode(Layout.self, from: Data(contentsOf: spritesDirectory.appendingPathComponent("layout.json")))
        for state in layout.states.keys {
            let url = spritesDirectory.appendingPathComponent("\(state).png")
            guard let image = NSImage(contentsOf: url)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                throw CocoaError(.fileReadCorruptFile, userInfo: [NSFilePathErrorKey: url.path])
            }
            sprites[state] = image
        }
        appIcon = Self.render(NSImage(contentsOf: appIconURL) ?? NSApp.applicationIconImage, size: 512)
    }

    func sprite(_ state: String) -> CGImage { sprites[state]! }

    /// The frame of the row titled `title` in `state`, in panel points (top-left origin).
    func row(_ title: String, in state: String) -> CGRect {
        layout.states[state]?.first { $0.title == title }?.rect ?? .zero
    }

    /// A horizontal strip of a sprite, in panel points.
    func strip(_ state: String, y: CGFloat, height: CGFloat) -> CGImage? {
        let scale = CGFloat(sprite(state).height) / panelSize.height
        return sprite(state).cropping(to: CGRect(x: 0, y: y * scale, width: panelSize.width * scale, height: height * scale))
    }

    func crop(_ state: String, _ rect: CGRect) -> CGImage? {
        let scale = CGFloat(sprite(state).height) / panelSize.height
        return sprite(state).cropping(to: CGRect(x: rect.minX * scale, y: rect.minY * scale,
                                                 width: rect.width * scale, height: rect.height * scale))
    }

    /// The Finder icon for a file extension ("folder" for a folder).
    func icon(_ ext: String) -> CGImage {
        if let cached = icons[ext] { return cached }
        let type: UTType = ext == "folder" ? .folder : (UTType(filenameExtension: ext) ?? .data)
        let image = Self.render(NSWorkspace.shared.icon(for: type), size: 256)
        icons[ext] = image
        return image
    }

    private static func render(_ image: NSImage, size: Int) -> CGImage {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                   bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
        NSGraphicsContext.restoreGraphicsState()
        return rep.cgImage!
    }
}
