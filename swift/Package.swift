// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PraxoCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "PraxoCore", targets: ["PraxoCore"]),
        .executable(name: "praxo-conformance", targets: ["PraxoConformance"]),
    ],
    targets: [
        .target(name: "PraxoCore"),
        .executableTarget(name: "PraxoConformance", dependencies: ["PraxoCore"]),
        .testTarget(name: "PraxoCoreTests", dependencies: ["PraxoCore"]),
    ]
)
