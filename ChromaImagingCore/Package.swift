// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ChromaImagingCore",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .visionOS(.v1)
    ],
    products: [
        // This is the product ChromaEngineKit will depend on.
        .library(
            name: "ChromaImagingCore",
            targets: ["ChromaImagingCore"]
        )
    ],
    targets: [
        // Prebuilt ITK xcframework
        .binaryTarget(
            name: "ChromaITK",
            path: "ThirdParty/ITK/ITK.xcframework"
        ),

        // ObjC++ bridge around ITK (C++ + public headers)
        .target(
            name: "ITKBridge",
            dependencies: ["ChromaITK"],
            path: "Sources/ITKBridge",
            sources: ["src"],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("../../ThirdParty/ITK/ITK.xcframework/Headers")
            ],
            cxxSettings: [
                .headerSearchPath("../../ThirdParty/ITK/ITK.xcframework/Headers"),
                .unsafeFlags(["-std=c++17"]),
                .define("ITK_LEGACY_SILENT", to: "1"),
                .define("NDEBUG")
            ],
            linkerSettings: [
                .linkedFramework("Accelerate", .when(platforms: [.iOS, .macOS, .visionOS])),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("Foundation")
            ]
        ),

        // Public Swift API (pure Swift, no headers)
        .target(
            name: "ChromaImagingCore",
            dependencies: ["ITKBridge"],
            // This is your canonical Swift tree:
            // Sources/ChromaImagingCore/
            //   ChromaImagingCore.swift
            //   Errors/
            //   ITK/
            //   Utils/
            path: "Sources/ChromaImagingCore"
        ),

        .testTarget(
            name: "ChromaImagingCoreTests",
            dependencies: ["ChromaImagingCore"],
            path: "Tests/ImagingCoreTests"
        )
    ]
)
