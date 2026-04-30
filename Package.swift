// swift-tools-version: 5.9
import PackageDescription

// AppState's pre-existing Timer + [weak self] + Task { @MainActor in ... }
// pattern, inherited from upstream Zoidberg, is treated as a warning under
// Xcode 26's local Swift 6 toolchain but as a strict-concurrency error on
// the GitHub macos-14 runner's toolchain. Pin both targets to minimal
// concurrency checking so the SwiftPM build path matches the Xcode path
// (project.pbxproj already has SWIFT_VERSION = 5.0 with no strict-concurrency
// override). Modernizing those patterns to MainActor.assumeIsolated is a
// separate refactor.
let appTargetSwiftSettings: [SwiftSetting] = [
    .unsafeFlags(["-strict-concurrency=minimal"])
]

let package = Package(
    name: "Flytrap",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Flytrap", targets: ["Flytrap"])
    ],
    dependencies: [
        .package(url: "https://github.com/soffes/HotKey", from: "0.2.1")
    ],
    targets: [
        .executableTarget(
            name: "Flytrap",
            dependencies: ["HotKey"],
            path: "Flytrap",
            // These are bundled into the .app by Flytrap.xcodeproj's
            // Resources build phase. SwiftPM has no equivalent of that
            // phase — without exclude, it warns about "unhandled files".
            exclude: [
                "Info.plist",
                "Flytrap.icns",
                "MenubarIcon.png",
                "MenubarIcon@2x.png",
            ],
            swiftSettings: appTargetSwiftSettings
        ),
        .testTarget(
            name: "FlytrapTests",
            dependencies: ["Flytrap"],
            path: "FlytrapTests",
            swiftSettings: appTargetSwiftSettings
        )
    ],
    // Pin language version to match Flytrap.xcodeproj's SWIFT_VERSION = 5.0.
    swiftLanguageVersions: [.v5]
)
