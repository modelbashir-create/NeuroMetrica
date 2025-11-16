// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DCMTKLoader",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "DCMTKLoader",
            targets: ["DCMTKLoader"]
        )
    ],
    targets: [

        // Objective-C++ target
        .target(
            name: "DCMTKLoaderObjC",
            path: "Sources/DCMTKLoaderObjC",
            publicHeadersPath: ".",
            cxxSettings: [
                .headerSearchPath("."),
                .define("DCMTK_LOADER", to: "1")
            ]
        ),

        // Swift target
        .target(
            name: "DCMTKLoader",
            dependencies: ["DCMTKLoaderObjC"],
            path: "Sources/DCMTKLoader"
        ),

        .testTarget(
            name: "DCMTKLoaderTests",
            dependencies: ["DCMTKLoader"],
            path: "Tests/DCMTKLoaderTests"
        )
    ]
)
