# DCMTK XCFramework Packaging

Run the build script from the repository root to generate a universal `DCMTK.xcframework` for macOS, iOS, iPadOS, tvOS, and visionOS using only the vendored DCMTK 3.6.9 sources:

```sh
./build_dcmtk_xcframework.sh
```

The script assembles static libraries for the following components into a single XCFramework: `ofstd`, `oflog`, `dcmdata`, `dcmimgle`, `dcmimage`, `dcmjpeg`, `dcmjpls`, `dcmect`, `dcmfg`, `dcmiod`, `dcmpmap`, `dcmrt`, `dcmseg`, `dcmsr`, `dcmnet`, `dcmqrdb`, `dcmpstat`, `dcmtls`, `dcmsign`, and `dcmtract`. Output is written to `DCMTKArtifacts/DCMTK.xcframework` with build and install intermediates under `DCMTKBuild/` and `DCMTKInstall/`.

The script follows the DCMTK 3.6.9 `INSTALL` cross-compilation guidance for Apple platforms: non-macOS variants use the documented CMake cache flags to avoid try-run checks, rely on built-in oficonv data, and disable Doxygen and command-line tools to keep the build lean.

## Swift Package manifest snippet
Add the following to `NeuroMetricaWorkspace/Package.swift` (or the relevant workspace-level manifest) to consume the generated XCFramework as a binary target and a convenience product your `DCMTKLoader` package can depend on:

```swift
.binaryTarget(
    name: "DCMTKBinary",
    path: "DCMTKArtifacts/DCMTK.xcframework"
),
.library(
    name: "DCMTKLib",
    targets: ["DCMTKBinary"]
)
```

Then add `DCMTKLib` to the dependencies for `DCMTKLoader` (or any other client target) within the same manifest.
