import Carbon.HIToolbox
import BiuBiuCore

/// Registers one global shortcut through Carbon, which needs no Accessibility permission.
@MainActor
final class HotKeyCenter {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var action: (() -> Void)?

    /// Returns false when the system refuses the combination (for example, another app owns it).
    func register(_ combo: HotKeyCombo, action: @escaping () -> Void) -> Bool {
        unregister()
        installHandlerIfNeeded()
        self.action = action
        let id = EventHotKeyID(signature: OSType(0x4269_5569), id: 1) // "BiUi"
        let status = RegisterEventHotKey(combo.keyCode, combo.carbonModifiers, id,
                                         GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr {
            hotKeyRef = nil
            return false
        }
        return true
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let userData = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
            MainActor.assumeIsolated { center.action?() }
            return noErr
        }, 1, &spec, userData, &handlerRef)
    }
}
