// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ChromaImagingKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ChromaImagingKit",
            targets: ["ChromaImagingKit"]
        )
    ],
    dependencies: [
        .package(path: "../DCMTKLoader")
    ],
    targets: [
        .target(
            name: "CNifti",
            path: "Sources/CNifti",
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath("nifti2"),
                .headerSearchPath("znzlib"),
                .unsafeFlags(
                    ["-Wno-shorten-64-to-32"],
                    .when(platforms: [.macOS, .iOS, .tvOS])
                ),
                .define("HAVE_ZLIB", .when(platforms: [.iOS, .macOS, .tvOS]))
            ],
            linkerSettings: [
                .linkedLibrary("z", .when(platforms: [.iOS, .macOS, .tvOS]))
            ]
        ),
        .target(
            name: "ChromaImagingKit",
            dependencies: [
                "CNifti",
                .product(name: "DCMTKLoader", package: "dcmtkloader")
            ],
            path: "Sources/ChromaImagingKit"
        ),
        .testTarget(
            name: "ChromaImagingKitTests",
            dependencies: ["ChromaImagingKit"],
            path: "Tests/ChromaImagingKitTests"
        )
    ]
)
