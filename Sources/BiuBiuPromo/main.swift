import AppKit

// BiuBiuPromo renders the README promo video from the real panel sprites (see scripts/make-promo.sh):
//   BiuBiuPromo --sprites <dir> --icon <AppIcon.icns> --out <dir> [--preview t1,t2,...]
// --preview writes single frames as PNG instead of the video.

@MainActor
func argument(_ name: String) -> String? {
    guard let index = CommandLine.arguments.firstIndex(of: name), CommandLine.arguments.count > index + 1 else { return nil }
    return CommandLine.arguments[index + 1]
}

@MainActor
func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("BiuBiuPromo: \(message)\n".utf8))
    exit(1)
}

@MainActor
func runFFmpeg(_ arguments: [String], input: ((FileHandle) throws -> Void)? = nil) {
    // Writing to ffmpeg after it exited raises SIGPIPE; ignoring it turns that into a thrown error below.
    signal(SIGPIPE, SIG_IGN)
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y"] + arguments
    let pipe = Pipe()
    if input != nil { process.standardInput = pipe }
    do { try process.run() } catch { fail("could not start ffmpeg: \(error)") }
    var writeError: Error?
    if let input {
        do { try input(pipe.fileHandleForWriting) } catch { writeError = error }
        try? pipe.fileHandleForWriting.close()
    }
    process.waitUntilExit()
    if process.terminationStatus != 0 || writeError != nil {
        fail("ffmpeg failed (\(writeError.map { "\($0)" } ?? "exit \(process.terminationStatus)")): \(arguments.joined(separator: " "))")
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
guard let spritesPath = argument("--sprites"), let iconPath = argument("--icon"), let outPath = argument("--out") else {
    fail("usage: BiuBiuPromo --sprites <dir> --icon <AppIcon.icns> --out <dir> [--preview t1,t2,...]")
}
let out = URL(fileURLWithPath: outPath)
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
let assets: Assets
do { assets = try Assets(spritesDirectory: URL(fileURLWithPath: spritesPath), appIconURL: URL(fileURLWithPath: iconPath)) } catch {
    fail("could not load sprites: \(error)")
}
let canvas = Canvas(width: 1920, height: 1080)
let storyboard = Storyboard(canvas: canvas, assets: assets)
let fps = 30.0

if let preview = argument("--preview") {
    for time in preview.split(separator: ",").compactMap({ Double($0) }) {
        storyboard.draw(time)
        let rep = NSBitmapImageRep(cgImage: canvas.ctx.makeImage()!)
        let url = out.appendingPathComponent(String(format: "frame-%05.2f.png", time))
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
        print("Wrote \(url.path)")
    }
    exit(0)
}

// Soundtrack.
var soundtrack = Soundtrack()
soundtrack.compose()
let audioURL = out.appendingPathComponent("soundtrack.wav")
do { try soundtrack.wav().write(to: audioURL) } catch { fail("could not write the soundtrack: \(error)") }
print("Wrote \(audioURL.path)")

// Video: raw frames straight into ffmpeg.
let videoURL = out.appendingPathComponent("biubiu-promo.mp4")
let frames = Int(Cue.duration * fps)
let started = Date()
runFFmpeg([
    "-f", "rawvideo", "-pix_fmt", "bgra", "-s", "1920x1080", "-r", "\(Int(fps))", "-i", "-",
    "-i", audioURL.path,
    "-c:v", "libx264", "-preset", "slow", "-crf", "23", "-pix_fmt", "yuv420p", "-profile:v", "high",
    "-c:a", "aac", "-b:a", "160k", "-shortest", "-movflags", "+faststart", videoURL.path,
]) { handle in
    for frame in 0..<frames {
        try autoreleasepool {
            storyboard.draw(Double(frame) / fps)
            try handle.write(contentsOf: canvas.pixels)
        }
        if frame % 150 == 0 { print("Frame \(frame)/\(frames) (\(Int(Date().timeIntervalSince(started))) s)") }
    }
}
print("Wrote \(videoURL.path)")

// Teaser GIF for the top of the README: the shortcut, biu biu, and the timeline appearing.
let gifURL = out.appendingPathComponent("biubiu-teaser.gif")
runFFmpeg([
    "-ss", "7.8", "-t", "7.2", "-i", videoURL.path,
    // Ordered dithering and a small palette keep the gradients under 2 MB.
    "-filter_complex", "fps=12,scale=720:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=3:diff_mode=rectangle",
    gifURL.path,
])
print("Wrote \(gifURL.path)")
try? FileManager.default.removeItem(at: audioURL)
