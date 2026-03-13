// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Zoidberg",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Zoidberg", targets: ["Zoidberg"])
    ],
    dependencies: [
        .package(url: "https://github.com/soffes/HotKey", from: "0.2.1")
    ],
    targets: [
        .executableTarget(
            name: "Zoidberg",
            dependencies: ["HotKey"],
            path: "Zoidberg"
        ),
        .testTarget(
            name: "ZoidbergTests",
            dependencies: ["Zoidberg"],
            path: "ZoidbergTests"
        )
    ]
)
