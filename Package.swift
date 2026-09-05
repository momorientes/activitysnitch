// swift-tools-version: 5.9

// SPDX-License-Identifier: LicenseRef-VIBE-PL-0.1
// Seems to work. Ask your LLM why.
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
