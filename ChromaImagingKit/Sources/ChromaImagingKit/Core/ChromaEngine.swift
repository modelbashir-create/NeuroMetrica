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
public struct ChromaEngine {

    public init() {}

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
    /// Pipeline:
    /// 1. Use SliceExtractGPU to pull out the requested slice (AX/COR/SAG).
    /// 2. Apply WW/WL on CPU via WindowLevelCPU (vDSP‑based).
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
        let slicer = SliceExtractGPU()

        // Adjust the method name/parameters if your SliceExtractGPU differs.
        let rawSlice = try slicer.extractSlice(
            from: volume,
            orientation: orientation,
            index: index
        )

        // Apply window/level on CPU. Adjust API if your implementation differs.
        let windowedSlice = WindowLevelCPU.apply(
            to: rawSlice,
            window: window,
            level: level
        )

        return windowedSlice
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

// Temporary adapter for SliceExtractGPU until its public API is finalized.
// This keeps ChromaEngine compiling and gives a single high-level entry point
// for slice extraction that we can later wire to the real GPU implementation.
fileprivate enum SliceExtractError: Error {
    case invalidIndex
    case outOfBounds
    case orientationNotImplemented
}

extension SliceExtractGPU {
    func extractSlice(
        from volume: CIImageVolume,
        orientation: SliceOrientation,
        index: Int
    ) throws -> CIImage2D {

        let width = volume.width
        let height = volume.height
        let depth = volume.depth
        let voxels = volume.voxels

        switch orientation {
        case .axial:
            // Axial: index runs along Z, slice is a contiguous XY plane.
            guard index >= 0, index < depth else {
                throw SliceExtractError.invalidIndex
            }

            let sliceCount = width * height
            let zOffset = index * sliceCount
            let end = zOffset + sliceCount

            guard end <= voxels.count else {
                throw SliceExtractError.outOfBounds
            }

            let sliceVoxels = Array(voxels[zOffset ..< end])

            return CIImage2D(
                width: width,
                height: height,
                pixels: sliceVoxels
            )

        case .coronal, .sagittal:
            // TODO: implement coronal and sagittal extraction using proper strides.
            throw SliceExtractError.orientationNotImplemented
        }
    }
}
