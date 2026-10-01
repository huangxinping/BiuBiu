import AppKit

package struct VolumeInfo: Hashable, Sendable {
    package var url: URL
    package var name: String
    package var isRemovable: Bool
    package var isEjectable: Bool
    package var isLocal: Bool
    package var isRootFileSystem: Bool

    package init(url: URL, name: String, isRemovable: Bool, isEjectable: Bool, isLocal: Bool, isRootFileSystem: Bool) {
        self.url = url
        self.name = name
        self.isRemovable = isRemovable
        self.isEjectable = isEjectable
        self.isLocal = isLocal
        self.isRootFileSystem = isRootFileSystem
    }

    /// External drives, USB sticks, disk images and network shares — not the startup disk.
    package var isExternal: Bool {
        !isRootFileSystem && (isRemovable || isEjectable || !isLocal)
    }
}

/// Connected external volumes. Mount times are only known for volumes mounted while the app runs.
@MainActor
package final class VolumeSource: ActivitySource {
    package let id = "volumes"
    private var mountDates: [String: Date] = [:]
    private var observers: [NSObjectProtocol] = []
    private var onUpdate: (@MainActor ([ActivityItem]) -> Void)?
    private let now: () -> Date

    package init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    package func start(since: Date, onUpdate: @escaping @MainActor ([ActivityItem]) -> Void) {
        stop()
        self.onUpdate = onUpdate
        let center = NSWorkspace.shared.notificationCenter
        observers = [
            center.addObserver(forName: NSWorkspace.didMountNotification, object: nil, queue: .main) { [weak self] note in
                let url = note.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL
                MainActor.assumeIsolated {
                    if let url { self?.mountDates[url.standardizedFileURL.path] = self?.now() }
                    self?.publish()
                }
            },
            center.addObserver(forName: NSWorkspace.didUnmountNotification, object: nil, queue: .main) { [weak self] note in
                let url = note.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL
                MainActor.assumeIsolated {
                    if let url { self?.mountDates[url.standardizedFileURL.path] = nil }
                    self?.publish()
                }
            },
        ]
        publish()
    }

    package func stop() {
        observers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
        observers = []
        onUpdate = nil
    }

    /// Unmounts and ejects on a background thread; the completion runs on the main actor with nil on success.
    package func eject(_ url: URL, completion: @escaping @MainActor (Error?) -> Void) {
        Task.detached {
            do {
                try NSWorkspace.shared.unmountAndEjectDevice(at: url)
                await completion(nil)
            } catch {
                await completion(error)
            }
        }
    }

    package static func items(from volumes: [VolumeInfo], mountDates: [String: Date]) -> [ActivityItem] {
        volumes.filter(\.isExternal).map { volume in
            ActivityItem(url: volume.url, kind: .volume, event: .mounted,
                         date: mountDates[volume.url.standardizedFileURL.path],
                         displayName: volume.name, parentName: "")
        }
    }

    private func publish() {
        onUpdate?(Self.items(from: Self.mountedVolumes(), mountDates: mountDates))
    }

    private static func mountedVolumes() -> [VolumeInfo] {
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeIsRemovableKey, .volumeIsEjectableKey,
                                      .volumeIsLocalKey, .volumeIsRootFileSystemKey]
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys,
                                                         options: [.skipHiddenVolumes]) ?? []
        return urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return nil }
            return VolumeInfo(
                url: url,
                name: values.volumeName ?? url.lastPathComponent,
                isRemovable: values.volumeIsRemovable ?? false,
                isEjectable: values.volumeIsEjectable ?? false,
                isLocal: values.volumeIsLocal ?? true,
                isRootFileSystem: values.volumeIsRootFileSystem ?? false
            )
        }
    }
}
