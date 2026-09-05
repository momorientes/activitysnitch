// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ActivitySnitch",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "CProcInfo"),
        .executableTarget(
            name: "ActivitySnitch",
            dependencies: ["CProcInfo"]
        ),
    ]
)
