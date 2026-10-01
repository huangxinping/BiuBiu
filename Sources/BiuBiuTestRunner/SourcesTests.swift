import Foundation
import BiuBiuCore

@MainActor
enum SourcesTests {
    static var tests: [TestCase] { [
        TestCase("Sources: apps in ~/Applications are left to the app source, others stay files") {
            let apps = "/Users/me/Applications/"
            expect(SpotlightFileSource.isLeftToAppSource(contentType: "com.apple.application-bundle",
                                                         path: "/Users/me/Applications/Chrome Apps.localized/Gmail.app",
                                                         userApplicationsPath: apps))
            expect(!SpotlightFileSource.isLeftToAppSource(contentType: "com.apple.application-bundle",
                                                          path: "/Users/me/Downloads/Tool.app", userApplicationsPath: apps))
            expect(!SpotlightFileSource.isLeftToAppSource(contentType: "public.plain-text",
                                                          path: "/Users/me/Applications/readme.txt", userApplicationsPath: apps))
        },
        TestCase("Volumes: only external volumes, mount date when known") {
            let root = VolumeInfo(url: URL(fileURLWithPath: "/"), name: "Macintosh HD", isRemovable: false,
                                  isEjectable: false, isLocal: true, isRootFileSystem: true)
            let usb = VolumeInfo(url: URL(fileURLWithPath: "/Volumes/T7"), name: "T7", isRemovable: true,
                                 isEjectable: true, isLocal: true, isRootFileSystem: false)
            let nas = VolumeInfo(url: URL(fileURLWithPath: "/Volumes/share"), name: "share", isRemovable: false,
                                 isEjectable: false, isLocal: false, isRootFileSystem: false)
            let internalData = VolumeInfo(url: URL(fileURLWithPath: "/Volumes/Data2"), name: "Data2", isRemovable: false,
                                          isEjectable: false, isLocal: true, isRootFileSystem: false)
            let mounted = Date(timeIntervalSince1970: 5)
            let items = VolumeSource.items(from: [root, usb, nas, internalData], mountDates: ["/Volumes/T7": mounted])
            expectEqual(items.map(\.displayName), ["T7", "share"])
            expectEqual(items.first?.date, mounted)
            expect(items.last?.date == nil)
            expectEqual(items.first?.kind, .volume)
        },
    ] }
}
