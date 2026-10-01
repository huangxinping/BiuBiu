// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BiuBiu",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "BiuBiuCore"),
        .executableTarget(name: "BiuBiu", dependencies: ["BiuBiuCore"]),
        .executableTarget(name: "BiuBiuTestRunner", dependencies: ["BiuBiuCore"]),
    ]
)
