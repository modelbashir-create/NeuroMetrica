//
//  ChromaEngine.swift
//  ChromaEngineKit
//
//  High-level façade over ChromaImagingCore + ITK-backed IO.
//
//  NeuroMetrica (and any other app) should depend only on this type
//  via `ChromaEngineBridge` instead of talking directly to ITK or
//  low-level GPU/CPU kernels.
//

import Foundation
import ChromaImagingCore   // ITKImageIO + ITKImageDescriptor

// MARK: - Error Type

public enum ChromaEngineError: Error, LocalizedError {
    case notImplemented(String)

    public var errorDescription: String? {
        switch self {
        case .notImplemented(let feature):
            return "\(feature) is not implemented yet in ChromaEngine."
        }
    }
}

// MARK: - Engine

/// High-level engine façade used by NeuroMetrica.
///
/// IO DESIGN (Architecture 2.0)
/// -----------------------------
/// - All real-world file/series reading (DICOM, NIfTI, NRRD, MHA, …)
///   is owned by ChromaImagingCore’s ITK bridge.
/// - ChromaEngine exposes format-specific async APIs that delegate to
///   that IO layer. For now the methods are stubs that clearly throw
///   `notImplemented` but the *signatures* are stable.
///
/// PROCESSING DESIGN
/// -----------------
/// - Slices and projections operate on the canonical volume model
///   (`CImageVolume`) and return `CIImage2D` for the UI layer.
/// - Later we can route slice + WW/WL through ITK vs Native backends
///   without changing this public surface.
public struct ChromaEngine: Sendable {

    // MARK: - Init

    static let sharedMetalService = MetalSliceRenderService()
#if DEBUG
    static let renderLogQueue = DispatchQueue(label: "ChromaEngine.RenderLogQueue")
    static var lastRenderPath: String?
    static var lastFallbackReason: String?
    static let geometryLogQueue = DispatchQueue(label: "ChromaEngine.GeometryLogQueue")
    static var geometryValidationLogged: Set<ObjectIdentifier> = []
#endif

    /// Default configuration.
    ///
    /// In the future this could accept a `ChromaEngineConfig` with
    /// backend choices (ITK vs Native), verification mode, etc.
    public var config: ChromaEngineConfig

    public init(config: ChromaEngineConfig = .standard) {
        self.config = config
    }

#if DEBUG
    public static func setGPUDebugForcedError(_ error: MetalSliceRendererError?) {
        sharedMetalService.setDebugForcedError(error)
    }

    public static func getLastRenderPath() -> String? {
        renderLogQueue.sync { lastRenderPath }
    }

    public static func getLastFallbackReason() -> String? {
        renderLogQueue.sync { lastFallbackReason }
    }
#endif

    // MARK: - Volume Loading (ITK-backed IO)

    /// Load a NIfTI volume from disk.
    ///
    /// Long-term: delegate to ITKImageIO / ITK bridge in
    /// ChromaImagingCore.
    public func loadNiftiVolume(from url: URL) async throws -> EngineVolumeDescriptor {
        try loadSingleFileVolume(from: url, sourceFormat: .nifti)
    }

    /// Load a DICOM series from a directory.
    ///
    /// Long-term: delegate to ITK DICOM series reader (GDCM/DCMTK)
    /// via the ITK bridge.
    public func loadDicomSeries(from directoryURL: URL) async throws -> EngineVolumeDescriptor {
        let descriptor = try ITKImageIO.loadVolume(
            at: directoryURL,
            formatHint: .dicomSeries,
            dicomBackend: mapDicomBackend(config.dicomBackend)
        )
        return convertDescriptorToVolume(descriptor, sourceFormat: .dicom, sourceDescription: directoryURL.path)
    }

    /// Invalidate GPU cache entries for a specific volume.
    public func invalidateGPUCache(for volume: CImageVolume) {
        ChromaEngine.sharedMetalService.invalidate(volume: volume)
    }

    // MARK: - Slice Generation + Window/Level

    /// Extract a 2D slice from a volume and apply window/level.
    ///
    /// - Parameters:
    ///   - volume: Canonical engine volume.
    ///   - orientation: Axial / coronal / sagittal.
    ///   - index: Zero-based slice index for that orientation.
    ///   - window: Window width.
    ///   - level: Window level (center).
    ///
    /// - Returns: A `CIImage2D` ready for conversion to CGImage /
    ///            SwiftUI `Image` in the app layer.
    public func makeSlice(
        from volume: CImageVolume,
        orientation: SliceOrientation,
        index: Int,
        window: Float,
        level: Float
    ) async throws -> CIImage2D {
        try makeSlice2D(
            from: volume,
            orientation: orientation,
            index: index,
            window: window,
            level: level
        )
    }

    /// Fast-path 2D slice extraction (no resampling, no patient-space math).
    public func makeSlice2D(
        from volume: CImageVolume,
        orientation: SliceOrientation,
        index: Int,
        window: Float,
        level: Float
    ) throws -> CIImage2D {
        let rescaleSlope = volume.rescaleSlope
        let rescaleIntercept = volume.rescaleIntercept
        let interpolation: MPRInterpolation = .linear

        if config.useGPUSliceRendering {
            let request = MetalSliceRenderRequest(
                volume: volume,
                orientation: orientation,
                index: index,
                window: window,
                level: level,
                rescaleSlope: Float(rescaleSlope),
                rescaleIntercept: Float(rescaleIntercept),
                interpolation: interpolation
            )
            #if DEBUG
            if config.enableGPUDebugComparison {
                let cpuSlice = try makeSlicePatientSpace(
                    from: volume,
                    orientation: orientation,
                    index: index,
                    window: window,
                    level: level,
                    rescaleSlope: rescaleSlope,
                    rescaleIntercept: rescaleIntercept,
                    interpolation: interpolation
                )
                do {
                    let gpuSlice = try ChromaEngine.sharedMetalService.renderSlice(request: request)
                    logRenderPath("GPU", reason: nil)
                    debugCompareGPUOutput(
                        gpuSlice: gpuSlice,
                        cpuSlice: cpuSlice,
                        volume: volume,
                        orientation: orientation,
                        index: index,
                        window: window,
                        level: level
                    )
                    return gpuSlice
                } catch {
                    logRenderPath("CPU", reason: "gpu_fallback:\(fallbackReason(for: error))")
                    return cpuSlice
                }
            }
            #endif
            do {
                let slice = try ChromaEngine.sharedMetalService.renderSlice(request: request)
                logRenderPath("GPU", reason: nil)
                return slice
            } catch {
                logRenderPath("CPU", reason: "gpu_fallback:\(fallbackReason(for: error))")
            }
        } else {
            logRenderPath("CPU", reason: "gpu_disabled")
        }
        return try makeSlicePatientSpace(
            from: volume,
            orientation: orientation,
            index: index,
            window: window,
            level: level,
            rescaleSlope: rescaleSlope,
            rescaleIntercept: rescaleIntercept,
            interpolation: interpolation
        )
    }

    /// Minimal volume rendering in native IJK space (no canonicalization).
    /// CPU/GPU share identical accumulation + WW/WL mapping; CPU remains authoritative.
    public func renderVolume2D(
        from volume: CImageVolume,
        orientation: SliceOrientation,
        window: Float,
        level: Float,
        step: Float = 1.0
    ) throws -> CIImage2D {
        if config.useGPUSliceRendering {
            let request = MetalVolumeRenderRequest(
                volume: volume,
                orientation: orientation,
                window: window,
                level: level,
                step: step
            )
            #if DEBUG
            if config.enableGPUDebugComparison {
                let cpuImage = try makeVolumeRenderCPU(from: volume, orientation: orientation, window: window, level: level, step: step)
                do {
                    let gpuImage = try ChromaEngine.sharedMetalService.renderVolume(request: request)
                    logRenderPath("GPU", reason: nil)
                    debugCompareGPUVolumeOutput(
                        gpuImage: gpuImage,
                        cpuImage: cpuImage,
                        orientation: orientation,
                        window: window,
                        level: level,
                        step: step
                    )
                    return gpuImage
                } catch {
                    logRenderPath("CPU", reason: "gpu_fallback:\(fallbackReason(for: error))")
                    return cpuImage
                }
            }
            #endif
            do {
                let image = try ChromaEngine.sharedMetalService.renderVolume(request: request)
                logRenderPath("GPU", reason: nil)
                return image
            } catch {
                logRenderPath("CPU", reason: "gpu_fallback:\(fallbackReason(for: error))")
            }
        } else {
            logRenderPath("CPU", reason: "gpu_disabled")
        }
        return try makeVolumeRenderCPU(from: volume, orientation: orientation, window: window, level: level, step: step)
    }

}
