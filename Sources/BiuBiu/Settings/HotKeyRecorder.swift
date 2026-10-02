import AppKit
import BiuBiuCore

/// A button that records the next key combination. Esc cancels; Delete clears the shortcut.
@MainActor
final class HotKeyRecorder: NSButton {
    var combo: HotKeyCombo? { didSet { updateTitle() } }
    var onChange: ((HotKeyCombo?) -> Void)?
    /// Lets the app pause the global shortcut while recording, so pressing it doesn't toggle the panel.
    var onRecordingChanged: ((Bool) -> Void)?
    private var monitor: Any?
    private var isRecording = false { didSet { updateTitle(); onRecordingChanged?(isRecording) } }

    init(combo: HotKeyCombo?) {
        self.combo = combo
        super.init(frame: .zero)
        bezelStyle = .push
        target = self
        action = #selector(clicked)
        widthAnchor.constraint(greaterThanOrEqualToConstant: 140).isActive = true
        updateTitle()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private var windowObservers: [NSObjectProtocol] = []

    /// Leaving the window mid-recording (closing it or switching away) ends the recording, so the global
    /// shortcut is restored and keys are no longer swallowed.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        windowObservers.forEach(NotificationCenter.default.removeObserver)
        windowObservers = []
        guard let window else { return }
        for name in [NSWindow.willCloseNotification, NSWindow.didResignKeyNotification] {
            windowObservers.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    if self?.isRecording == true { self?.stopRecording() }
                }
            })
        }
    }

    @objc private func clicked() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            self.handle(event)
            return nil
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
    }

    private func handle(_ event: NSEvent) {
        let modifiers = HotKeyModifiers(event.modifierFlags)
        switch (event.keyCode, modifiers.isEmpty) {
        case (53, true):
            stopRecording()
        case (51, true), (117, true):
            combo = nil
            stopRecording()
            onChange?(nil)
        default:
            let candidate = HotKeyCombo(keyCode: UInt32(event.keyCode), modifiers: modifiers)
            guard candidate.isValid else {
                NSSound.beep()
                return
            }
            combo = candidate
            stopRecording()
            onChange?(candidate)
        }
    }

    private func updateTitle() {
        title = isRecording ? L("Type shortcut…") : (combo?.localizedDisplayString ?? L("Record Shortcut"))
    }
}
