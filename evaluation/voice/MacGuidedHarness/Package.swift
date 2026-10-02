// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "VoiceGuidedHarness",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift", exact: "0.31.6"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", revision: "604fae710a4e3324346fc59e3845952350acd4b7"),
        .package(url: "https://github.com/huggingface/swift-transformers", exact: "1.3.4"),
    ],
    targets: [
        .executableTarget(
            name: "voice-guided",
            dependencies: [
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXGuidedGeneration", package: "mlx-swift-lm"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "Tokenizers", package: "swift-transformers"),
            ]
        ),
    ]
)
