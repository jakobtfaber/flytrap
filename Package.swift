// swift-tools-version: 5.9
import PackageDescription

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
            path: "Flytrap"
        ),
        .testTarget(
            name: "FlytrapTests",
            dependencies: ["Flytrap"],
            path: "FlytrapTests"
        )
    ],
    // Pin to Swift 5 to match Flytrap.xcodeproj's SWIFT_VERSION = 5.0
    // build setting. Without this, newer Swift 6 toolchains (e.g. the
    // GitHub macOS-14 runner) treat AppState's pre-existing Timer +
    // [weak self] + Task { @MainActor in ... } pattern as strict-
    // concurrency errors instead of warnings, and `swift test` fails.
    // The Xcode build path is already Swift 5; this aligns SwiftPM.
    // Modernizing those patterns to MainActor.assumeIsolated is a
    // separate refactor.
    swiftLanguageVersions: [.v5]
)
