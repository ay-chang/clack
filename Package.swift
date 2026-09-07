// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Clack",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Clack",
            path: "Sources/Clack"
        ),
        .testTarget(
            name: "ClackTests",
            dependencies: ["Clack"],
            path: "Tests/ClackTests"
        )
    ]
)
