import AppKit

@MainActor
final class AboutViewController: NSViewController {
    override init(nibName: NSNib.Name?, bundle: Bundle?) {
        super.init(nibName: nil, bundle: nil)
        title = L("About")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func loadView() {
        // A build without a bundle (swift run) has no app icon; show the menu bar symbol instead of a folder.
        let hasIcon = Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") != nil
        let icon = NSImageView(image: hasIcon ? NSApp.applicationIconImage
            : NSImage(systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: "BiuBiu")!
                .withSymbolConfiguration(.init(pointSize: 48, weight: .regular))!)
        icon.widthAnchor.constraint(equalToConstant: 64).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 64).isActive = true
        let name = NSTextField(labelWithString: "BiuBiu")
        name.font = .systemFont(ofSize: 18, weight: .semibold)
        let version = NSTextField(labelWithString: String(format: L("Version %@"), AppInfo.version))
        version.textColor = .secondaryLabelColor
        let blurb = NSTextField(wrappingLabelWithString: L("Your recent files, folders, apps and drives, one shortcut away."))
        blurb.alignment = .center
        let github = NSButton(title: L("GitHub"), target: self, action: #selector(openRepository))
        let updates = NSButton(title: L("Check for Updates"), target: self, action: #selector(openReleases))
        let buttons = NSStackView(views: [github, updates])
        buttons.isHidden = AppInfo.repositoryURL == nil

        let stack = NSStackView(views: [icon, name, version, blurb, buttons])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 40, bottom: 24, right: 40)
        NSLayoutConstraint.activate([
            stack.widthAnchor.constraint(equalToConstant: 480),
            blurb.widthAnchor.constraint(lessThanOrEqualToConstant: 400),
        ])
        view = stack
    }

    @objc private func openRepository() {
        if let url = AppInfo.repositoryURL { NSWorkspace.shared.open(url) }
    }

    @objc private func openReleases() {
        if let url = AppInfo.releasesURL { NSWorkspace.shared.open(url) }
    }
}
