// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ChromaEngineKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        // The library your app will import: import ChromaEngineKit
        .library(
            name: "ChromaEngineKit",
            targets: ["ChromaEngineKit"]
        )
    ],
    dependencies: [
        // Local dependency on the ITK bridge package
        .package(path: "../ChromaImagingCore")
    ],
    targets: [
        .target(
            name: "ChromaEngineKit",
            dependencies: [
                .product(name: "ChromaImagingCore", package: "ChromaImagingCore")
            ],
            path: "Sources/ChromaEngineKit",
            resources: [
                .process("Services/Rendering/Shaders")
            ]
        ),
        .testTarget(
            name: "ChromaEngineKitTests",
            dependencies: ["ChromaEngineKit"],
            path: "Tests/ChromaEngineKitTests"
        )
    ]
)
