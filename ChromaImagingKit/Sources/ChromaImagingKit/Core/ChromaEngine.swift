//
//  ChromaEngine.swift
//  ChromaImagingKit
//
//  Created by Mohamed Elbashir on 11/14/25.
//

import Foundation

/// High-level façade for the ChromaImagingKit engine.
///
/// The idea is that NeuroMetrica (or any app) talks to this type,
/// instead of directly calling into all the low-level loaders and
/// GPU/CPU processors. That way wiring is simpler and the engine
/// can evolve internally without breaking the app layer.
///
/// NOTE: The concrete types used here (NIfTILoader, SliceExtractGPU,
/// WindowLevelCPU, VolumeMapper) should already exist as scaffolds in
/// the package. If their APIs differ, we can adjust this façade to
/// match them.
public final class ChromaEngine {

    public var backend: ChromaProcessingBackend

    public init(backend: ChromaProcessingBackend = .gpu) {
        self.backend = backend
    }

    // MARK: - Loading

    /// Load a NIfTI volume from disk into a CIImageVolume.
    ///
    /// This is the preferred entry point for non‑DICOM volumes in the
    /// first versions of the app.
    @discardableResult
    public func loadNIfTI(at url: URL) throws -> CIImageVolume {
        let loader = NIfTILoader()
        return try loader.loadVolume(from: url)
    }

    // MARK: - Slices

    /// Extract a windowed slice from a volume for display.
    ///
    /// Pipeline (selected by `backend`):
    /// - GPU: Use SliceExtractGPU + WindowLevelGPU.
    /// - CPU: Use CPU voxel slicing + WindowLevelCPU (vDSP‑based).
    ///
    /// This returns a CIImage2D that the app can later convert to CGImage
    /// for display.
    public func makeSlice(
        from volume: CIImageVolume,
        orientation: SliceOrientation,
        index: Int,
        window: Float,
        level: Float
    ) throws -> CIImage2D {
        let rawSlice = try SliceExtractGPU.extractSlice(
            from: volume,
            orientation: orientation,
            index: index,
            backend: backend
        )

        switch backend {
        case .gpu:
            return WindowLevelGPU.apply(
                to: rawSlice,
                window: window,
                level: level
            )
        case .cpu:
            return WindowLevelCPU.apply(
                to: rawSlice,
                window: window,
                level: level
            )
        }
    }

    // MARK: - Projections (MIP)

    /// Compute a simple MIP (max‑intensity projection) for a given orientation.
    ///
    /// This is a higher‑level helper around VolumeMapper. It’s expected that
    /// VolumeMapper will internally handle any needed resampling or reductions.
    public func makeMIP(
        from volume: CIImageVolume,
        orientation: SliceOrientation
    ) throws -> CIImage2D {
        // TODO: Implement MIP using VolumeMapper when its API is finalized.
        // For now, throw an unsupported error to keep the engine compiling.
        struct MIPNotImplementedError: Error {}
        throw MIPNotImplementedError()
    }
}
