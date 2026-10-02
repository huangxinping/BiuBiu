import Foundation

package enum PanelCommand: Equatable, Sendable {
    case moveDown, moveUp, open, reveal, clearSearch, close, quickLook, togglePin, copyPath, openSettings
    /// Zero-based index into the visible categories.
    case selectCategory(Int)
}

/// Maps key presses in the panel to commands. Keys that are not commands fall through to the search field.
package enum PanelKeyMap {
    package static func command(keyCode: UInt16, modifiers: HotKeyModifiers, searchIsEmpty: Bool,
                                isComposing: Bool = false) -> PanelCommand? {
        // Pinyin and other input methods use Return, arrows, Esc and Space while composing.
        if isComposing { return nil }
        return switch (keyCode, modifiers) {
        case (125, []): .moveDown
        case (126, []): .moveUp
        case (36, []), (76, []): .open
        case (36, [.command]), (76, [.command]): .reveal
        // Esc clears the search first, and closes the panel once there is nothing to clear.
        case (53, []): searchIsEmpty ? .close : .clearSearch
        // Space previews only when there is nothing to type into; "季度 汇报" must still search.
        case (49, []) where searchIsEmpty: .quickLook
        case (16, [.command]): .quickLook
        case (35, [.command]): .togglePin
        case (8, [.command, .option]): .copyPath
        case (43, [.command]): .openSettings
        case (let code, [.command]): digitKeyCodes[code].map { .selectCategory($0 - 1) }
        default: nil
        }
    }

    /// kVK_ANSI_1 ... kVK_ANSI_6 → 1 ... 6
    private static let digitKeyCodes: [UInt16: Int] = [18: 1, 19: 2, 20: 3, 21: 4, 23: 5, 22: 6]
}
