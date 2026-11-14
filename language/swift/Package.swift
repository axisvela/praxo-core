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
        .executableTarget(name: "praxo-retry-example", dependencies: ["PraxoCore"], path: "examples/retry"),
        .executableTarget(name: "praxo-checkpoint-example", dependencies: ["PraxoCore"], path: "examples/checkpoint"),
        .executableTarget(name: "praxo-event-sink-example", dependencies: ["PraxoCore"], path: "examples/event-sink"),
        .executableTarget(name: "praxo-provider-fallback-example", dependencies: ["PraxoCore"], path: "examples/provider-fallback"),
        .executableTarget(name: "praxo-structured-output-example", dependencies: ["PraxoCore"], path: "examples/structured-output"),
        .executableTarget(name: "praxo-streaming-example", dependencies: ["PraxoCore"], path: "examples/streaming"),
        .executableTarget(name: "praxo-identity-policy-example", dependencies: ["PraxoCore"], path: "examples/identity-policy"),
        .executableTarget(name: "praxo-service-example", dependencies: ["PraxoCore"], path: "examples/service"),
        .executableTarget(name: "praxo-mcp-example", dependencies: ["PraxoCore"], path: "examples/mcp"),
        .testTarget(name: "PraxoCoreTests", dependencies: ["PraxoCore"]),
    ]
)
