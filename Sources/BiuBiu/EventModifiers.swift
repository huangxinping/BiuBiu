import AppKit
import BiuBiuCore

extension HotKeyModifiers {
    init(_ flags: NSEvent.ModifierFlags) {
        var result: HotKeyModifiers = []
        if flags.contains(.command) { result.insert(.command) }
        if flags.contains(.option) { result.insert(.option) }
        if flags.contains(.control) { result.insert(.control) }
        if flags.contains(.shift) { result.insert(.shift) }
        self = result
    }
}
