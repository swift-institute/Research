// swift-tools-version: 6.0
// SCRATCH-ONLY fixture generation vehicle for the N5 swift-certificates
// publication tree. Never ships; uses upstream apple/swift-certificates
// issuance APIs at the reviewed fork point to freeze a DER fixture corpus.
import PackageDescription

let package = Package(
    name: "fixture-gen",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-certificates.git",
            revision: "24ccdeeeed4dfaae7955fcac9dbf5489ed4f1a25"
        ),
        .package(
            url: "https://github.com/apple/swift-crypto.git",
            exact: "4.3.0"
        ),
    ],
    targets: [
        .executableTarget(
            name: "fixture-gen",
            dependencies: [
                .product(name: "X509", package: "swift-certificates"),
                .product(name: "Crypto", package: "swift-crypto"),
            ]
        )
    ]
)
