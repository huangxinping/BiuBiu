import AppKit
import BiuBiuCore

/// What the welcome window says about macOS privacy prompts. Chosen from the Task 1 probe results.
enum PrivacyNote {
    /// BiuBiu works without any prompt.
    case none
    /// macOS asks once per protected folder; tell the user to allow it.
    case expectPrompts
    /// Protected folders stay hidden unless BiuBiu gets Full Disk Access.
    case fullDiskAccess
}

@MainActor
final class WelcomeWindowController: NSWindowController {
    private let onDone: () -> Void
    private let launchCheckbox = NSButton(checkboxWithTitle: L("Open BiuBiu at login"), target: nil, action: nil)

    init(shortcut: String?, privacyNote: PrivacyNote, onDone: @escaping () -> Void) {
        self.onDone = onDone
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 300),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = L("Welcome to BiuBiu")
        window.isReleasedWhenClosed = false
        super.init(window: window)

        let title = NSTextField(labelWithString: L("Welcome to BiuBiu"))
        title.font = .systemFont(ofSize: 20, weight: .semibold)
        let intro = NSTextField(wrappingLabelWithString:
            L("BiuBiu lives in your menu bar and remembers the files you just opened, saved or downloaded."))
        let shortcutText = shortcut.map { String(format: L("Press %@ anywhere — even in full-screen apps — to open it."), $0) }
            ?? L("Click the menu bar icon to open it.")
        let shortcutLabel = NSTextField(wrappingLabelWithString: shortcutText)
        launchCheckbox.state = LaunchAtLogin.isEnabled ? .on : .off
        let done = NSButton(title: L("Get Started"), target: self, action: #selector(finish))
        done.keyEquivalent = "\r"

        var views: [NSView] = [title, intro, shortcutLabel]
        switch privacyNote {
        case .none:
            break
        case .expectPrompts:
            views.append(NSTextField(wrappingLabelWithString:
                L("macOS may ask whether BiuBiu can access your Desktop, Documents or Downloads folder. Click Allow so those files can appear in the list.")))
        case .fullDiskAccess:
            views.append(NSTextField(wrappingLabelWithString:
                L("To list files from your Desktop, Documents and Downloads, BiuBiu needs Full Disk Access. Turn on BiuBiu in the list that opens.")))
            views.append(NSButton(title: L("Open Privacy Settings…"), target: self, action: #selector(openPrivacySettings)))
        }
        views += [launchCheckbox, done]
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 28, bottom: 24, right: 28)
        for case let label as NSTextField in views where label.isEditable == false && label.cell?.wraps == true {
            label.widthAnchor.constraint(equalToConstant: 364).isActive = true
        }
        window.contentView = stack
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func present() {
        window?.center()
        NSApp.activate()
        showWindow(nil)
    }

    @objc private func openPrivacySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
    }

    @objc private func finish() {
        try? LaunchAtLogin.setEnabled(launchCheckbox.state == .on)
        close()
        onDone()
    }
}
