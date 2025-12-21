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
import ChromaImagingCore   // CImageVolume, CIImage2D, SliceOrientation

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

    /// Default configuration.
    ///
    /// In the future this could accept a `ChromaEngineConfig` with
    /// backend choices (ITK vs Native), verification mode, etc.
    public init() {}

    // MARK: - Volume Loading (ITK-backed IO)

    /// Load a NIfTI volume from disk.
    ///
    /// Long-term: delegate to ITKImageIO / ITK bridge in
    /// ChromaImagingCore.
    public func loadNiftiVolume(from url: URL) async throws -> CImageVolume {
        throw ChromaEngineError.notImplemented("NIfTI volume loading")
    }

    /// Load an NRRD volume from disk.
    ///
    /// Long-term: delegate to ITKImageIO / ITK bridge in
    /// ChromaImagingCore.
    public func loadNRRDVolume(from url: URL) async throws -> CImageVolume {
        throw ChromaEngineError.notImplemented("NRRD volume loading")
    }

    /// Load a DICOM series from a directory.
    ///
    /// Long-term: delegate to ITK DICOM series reader (GDCM/DCMTK)
    /// via the ITK bridge.
    public func loadDicomSeries(from directoryURL: URL) async throws -> CImageVolume {
        throw ChromaEngineError.notImplemented("DICOM series loading")
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
        throw ChromaEngineError.notImplemented("Slice extraction + WW/WL")
    }
}
