import Foundation

#if DEBUG

/// Debug-only GPU fallback harness.
///
/// Verifies CPU fallback behavior without requiring a Metal device.
struct MetalSliceDebugHarness {
    static func runFallbackChecks() -> [String] {
        var results: [String] = []

        results.append(runGPUDisabledCheck())
        results.append(runMetalUnavailableCheck())
        results.append(runUnsupportedVoxelTypeCheck())
        results.append(runKernelFailureCheck())

        return results
    }

    private static func runGPUDisabledCheck() -> String {
        let engine = ChromaEngine(config: ChromaEngineConfig(useGPUSliceRendering: false))
        let volume = makeVolume(componentsPerPixel: 1)
        do {
            _ = try engine.makeSlice2D(from: volume, orientation: .axial, index: 0, window: 100, level: 50)
            return "GPU disabled -> CPU path OK"
        } catch {
            return "GPU disabled -> CPU path failed: \(error)"
        }
    }

    private static func runMetalUnavailableCheck() -> String {
        let engine = ChromaEngine(config: ChromaEngineConfig(useGPUSliceRendering: true))
        ChromaEngine.setGPUDebugForcedError(.metalUnavailable)
        let volume = makeVolume(componentsPerPixel: 1)
        defer { ChromaEngine.setGPUDebugForcedError(nil) }
        do {
            _ = try engine.makeSlice2D(from: volume, orientation: .axial, index: 0, window: 100, level: 50)
            return "Metal unavailable -> CPU fallback OK"
        } catch {
            return "Metal unavailable -> CPU fallback failed: \(error)"
        }
    }

    private static func runUnsupportedVoxelTypeCheck() -> String {
        let engine = ChromaEngine(config: ChromaEngineConfig(useGPUSliceRendering: true))
        ChromaEngine.setGPUDebugForcedError(.unsupportedComponentsPerPixel)
        let volume = makeVolume(componentsPerPixel: 2)
        defer { ChromaEngine.setGPUDebugForcedError(nil) }
        do {
            _ = try engine.makeSlice2D(from: volume, orientation: .axial, index: 0, window: 100, level: 50)
            return "Unsupported voxel type -> CPU fallback OK"
        } catch {
            return "Unsupported voxel type -> CPU fallback failed: \(error)"
        }
    }

    private static func runKernelFailureCheck() -> String {
        let engine = ChromaEngine(config: ChromaEngineConfig(useGPUSliceRendering: true))
        ChromaEngine.setGPUDebugForcedError(.pipelineStateCreationFailed)
        let volume = makeVolume(componentsPerPixel: 1)
        defer { ChromaEngine.setGPUDebugForcedError(nil) }
        do {
            _ = try engine.makeSlice2D(from: volume, orientation: .axial, index: 0, window: 100, level: 50)
            return "Kernel failure -> CPU fallback OK"
        } catch {
            return "Kernel failure -> CPU fallback failed: \(error)"
        }
    }

    private static func makeVolume(componentsPerPixel: Int) -> CImageVolume {
        let size = 2
        let bytesPerComponent = 2
        let componentType: CIPixelComponentType = .uint16
        let voxelCount = size * size * size
        let valueCount = voxelCount * componentsPerPixel
        let byteCount = valueCount * bytesPerComponent
        let data = Data(count: byteCount)

        return CImageVolume(
            dimension: 3,
            sizeX: size,
            sizeY: size,
            sizeZ: size,
            sizeT: 1,
            spacingX: 1.0,
            spacingY: 1.0,
            spacingZ: 1.0,
            spacingT: 1.0,
            originX: 0.0,
            originY: 0.0,
            originZ: 0.0,
            originT: 0.0,
            direction: [
                1, 0, 0, 0,
                0, 1, 0, 0,
                0, 0, 1, 0,
                0, 0, 0, 1
            ],
            componentType: componentType,
            componentsPerPixel: componentsPerPixel,
            bytesPerComponent: bytesPerComponent,
            isSigned: false,
            voxelData: data
        )
    }
}

#endif
