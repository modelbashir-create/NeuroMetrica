//
//  ChromaEngine.swift
//  ChromaEngineKit
//
//  High-level façade for the ChromaImagingCore / ITK-based engine.
//
//  NeuroMetrica (or any app) should talk only to this type instead of
//  directly calling into low-level loaders and GPU/CPU processors.
//  This keeps wiring simple and lets the engine evolve internally
//  without breaking the app layer.
//

import Foundation
import ChromaImagingCore

/// High-level façade for the Chroma engine.
///
/// IO DESIGN (Architecture 2.0)
/// -----------------------------
/// - All production file/series reading (DICOM, NIfTI, NRRD, MHA, …)
///   is owned by ChromaImagingCore’s ITK bridge.
/// - ChromaEngine exposes format-agnostic volume loading APIs that
///   delegate to ITK-backed IO in ChromaImagingCore (e.g. ITKImageIO).
/// - Any legacy Swift loaders are reserved for tests/synthetic data
///   and are not called from NeuroMetrica for real user data.
///
/// RENDERING / PROCESSING
/// ----------------------
/// - Slices and projections are created from the engine’s volume model
///   (`CImageVolume`) and returned as `CIImage2D`.
/// - Window/level and other filters are implemented by pluggable
///   backends conforming to `ChromaProcessingBackend`:
///     • ITK-backed processing
///     • Native (Metal / vDSP / Swift) processing
/// - The app selects the backend via `ChromaEngine(backend: …)` and
///   never talks to ITK or native kernels directly.
public final class ChromaEngine {

    // MARK: - Nested Types

    /// High-level hint about the input volume format.
    ///
    /// `.automatic` should let the ITK-backed IO pick the right
    /// reader based on file extension / header inspection.
    public enum VolumeFormat {
        case automatic
        case dicomSeries
        case nifti
        case nrrd
        case mha
        case raw
    }

    public enum ChromaEngineError: Error {
        case ioUnavailable    // ITK-backed IO wrapper not wired yet
        case sliceUnavailable // Slice extraction not implemented yet
        case mipUnavailable   // MIP not implemented yet
    }

    // MARK: - Properties

    /// Processing backend used for WW/WL and other display-time
    /// processing (ITK vs Native). This may internally use CPU or GPU,
    /// but the app only cares about the backend kind.
    public var backend: ChromaProcessingBackend

    // MARK: - Init

    /// Designated initializer.
    ///
    /// The caller (usually `ChromaEngineBridge` in the app target)
    /// is responsible for constructing the concrete backend
    /// (e.g. ITKProcessingBackend or NativeProcessingBackend).
    public init(backend: ChromaProcessingBackend) {
        self.backend = backend
    }

    // MARK: - Volume Loading (ITK-backed)

    /// Load a volume from disk into a `CImageVolume` using the ITK-
    /// backed IO stack in ChromaImagingCore.
    ///
    /// The concrete implementation lives in the imaging core / ITK
    /// bridge. ChromaEngine keeps the signature stable so that the
    /// app and its ViewModels don’t depend on low-level details.
    ///
    /// - Parameters:
    ///   - url:    Location of the file or DICOM series entry point.
    ///   - format: Optional format hint; `.automatic` delegates
    ///             detection to the IO layer.
    ///
    /// - Returns: A `CImageVolume` suitable for slicing and rendering.
    ///
    /// - Throws: `ChromaEngineError.ioUnavailable` for now, until
    ///           the ITK-backed IO wrapper is wired up.
    @discardableResult
    public func loadVolume(
        at url: URL,
        format: VolumeFormat = .automatic
    ) throws -> CImageVolume {
        // TODO (next vertical slice):
        //   return try ITKImageIO.loadVolume(at: url, format: format)
        //
        // For now, keep the API stable and throw a clear error so the
        // app can be wired up without crashing.
        throw ChromaEngineError.ioUnavailable
    }

    // MARK: - Slices

    /// Extract a windowed slice from a volume for display.
    ///
    /// Target pipeline:
    /// - Use a core helper (in ChromaImagingCore) to extract a
    ///   `CIImage2D` slice for the requested orientation/index.
    /// - Pass that slice to the configured `backend` so it can apply
    ///   window/level and any per-backend processing (ITK vs Native).
    ///
    /// Current status: IO + slicing helpers are being refactored
    /// around ITK, so this method acts as a stable façade and will be
    /// wired to the core once those pieces are in place.
    ///
    /// - Parameters:
    ///   - volume:       The engine’s volume representation.
    ///   - orientation:  Axial / coronal / sagittal.
    ///   - index:        Slice index in that orientation.
    ///   - window:       WW value.
    ///   - level:        WL value.
    ///
    /// - Returns: A `CIImage2D` ready for conversion to CGImage /
    ///            SwiftUI `Image` in the app layer.
    ///
    /// - Throws: `ChromaEngineError.sliceUnavailable` until the
    ///           extraction path is implemented.
    public func makeSlice(
        from volume: CImageVolume,
        orientation: SliceOrientation,
        index: Int,
        window: Float,
        level: Float
    ) throws -> CIImage2D {
        // TODO (future vertical slice), roughly:
        //
        //   let rawSlice = try CoreSliceExtractor.extract(
        //       from: volume,
        //       orientation: orientation,
        //       index: index
        //   )
        //
        //   return try backend.makeWindowLeveledSlice(
        //       from: volume,
        //       orientation: orientation,
        //       sliceIndex: index,
        //       window: window,
        //       level: level
        //   )
        //
        throw ChromaEngineError.sliceUnavailable
    }

    // MARK: - Projections (MIP)

    /// Compute a simple MIP (max-intensity projection) for a given
    /// orientation.
    ///
    /// This will eventually wrap a core MIP/VolumeMapper helper in
    /// ChromaImagingCore and then pass the result through the backend
    /// if needed for display scaling.
    ///
    /// - Throws: `ChromaEngineError.mipUnavailable` until wired.
    public func makeMIP(
        from volume: CImageVolume,
        orientation: SliceOrientation
    ) throws -> CIImage2D {
        // TODO (future vertical slice): implement MIP using a dedicated
        // core helper in ChromaImagingCore.
        throw ChromaEngineError.mipUnavailable
    }
}
