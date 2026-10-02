import Foundation

package struct HotKeyModifiers: OptionSet, Codable, Hashable, Sendable {
    package let rawValue: UInt32
    package init(rawValue: UInt32) { self.rawValue = rawValue }

    package static let control = HotKeyModifiers(rawValue: 1 << 0)
    package static let option = HotKeyModifiers(rawValue: 1 << 1)
    package static let shift = HotKeyModifiers(rawValue: 1 << 2)
    package static let command = HotKeyModifiers(rawValue: 1 << 3)
}

/// A global shortcut: a virtual key code (kVK_*) plus modifiers.
package struct HotKeyCombo: Codable, Hashable, Sendable {
    package var keyCode: UInt32
    package var modifiers: HotKeyModifiers

    package init(keyCode: UInt32, modifiers: HotKeyModifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// ⌥⌘R (kVK_ANSI_R = 15).
    package static let defaultToggle = HotKeyCombo(keyCode: 15, modifiers: [.option, .command])

    /// A global shortcut must use at least one of ⌘ ⌥ ⌃; Shift alone would hijack normal typing.
    package var isValid: Bool {
        !modifiers.intersection([.command, .option, .control]).isEmpty && Self.keyNames[keyCode] != nil
    }

    /// Carbon modifier mask for RegisterEventHotKey (cmdKey, shiftKey, optionKey, controlKey).
    package var carbonModifiers: UInt32 {
        var mask: UInt32 = 0
        if modifiers.contains(.command) { mask |= 0x0100 }
        if modifiers.contains(.shift) { mask |= 0x0200 }
        if modifiers.contains(.option) { mask |= 0x0800 }
        if modifiers.contains(.control) { mask |= 0x1000 }
        return mask
    }

    package var displayString: String { displayString(localizingKeyName: { $0 }) }

    /// The shortcut as shown in the UI; `localize` translates key names such as "Space".
    package func displayString(localizingKeyName localize: (String) -> String) -> String {
        var s = ""
        if modifiers.contains(.control) { s += "⌃" }
        if modifiers.contains(.option) { s += "⌥" }
        if modifiers.contains(.shift) { s += "⇧" }
        if modifiers.contains(.command) { s += "⌘" }
        return s + localize(Self.keyNames[keyCode] ?? "?")
    }

    /// Names for US-layout virtual key codes.
    package static let keyNames: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7",
        27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
        36: "↩", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
        45: "N", 46: "M", 47: ".", 48: "⇥", 49: "Space", 50: "`",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11",
        105: "F13", 107: "F14", 109: "F10", 111: "F12", 113: "F15", 118: "F4",
        120: "F2", 122: "F1", 123: "←", 124: "→", 125: "↓", 126: "↑",
    ]
}
