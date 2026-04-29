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
    ]
)
