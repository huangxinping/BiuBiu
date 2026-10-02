import AppKit

if CommandLine.arguments.contains("--dump") {
    DumpMode.run()
}

if let index = CommandLine.arguments.firstIndex(of: "--screenshots"), CommandLine.arguments.count > index + 1 {
    ScreenshotMode.run(outputDirectory: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
