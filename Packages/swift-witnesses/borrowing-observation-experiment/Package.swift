// swift-tools-version: 6.3.3

import PackageDescription

let package = Package(
    name: "borrowing-observation-experiment",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "BorrowingObservation",
            path: "Sources",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
            ]
        ),
    ]
)
