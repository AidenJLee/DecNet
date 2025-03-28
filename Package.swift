// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.
// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "DecNet",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "DecNet",
            targets: ["DecNet"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "DecNet",
            dependencies: [],
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals"),
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "DecNetTests",
            dependencies: ["DecNet"]
        ),
        .executableTarget(
            name: "DecNetExamples",
            dependencies: ["DecNet"],
            path: "Examples"
        )
    ]
)
