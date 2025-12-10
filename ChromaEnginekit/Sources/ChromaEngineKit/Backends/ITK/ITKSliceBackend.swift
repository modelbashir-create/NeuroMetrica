//
//  ITKSliceBackend.swift
//  ChromaEngineKit
//
//  ITK-backed implementation of SliceBackend.
//  For now this is a placeholder that always throws `notImplemented`,
//  but the public surface is correct and stable.
//

import Foundation
import ChromaImagingCore

// MARK: - Error Type

public enum ITKSliceBackendError: Error {
    /// Placeholder: ITK slice extraction is not wired up yet.
    case notImplemented
}

// MARK: - Backend Type

/// ITK-backed slice extraction backend.
///
/// In the future this type will:
/// - Call into ITKBridge / ITKImageIO for slice extraction & resampling.
/// - Support axial / coronal / sagittal orientations.
/// - Respect physical spacing, direction cosines, etc.
public final class ITKSliceBackend: Sendable {
    public init() {}
}

// MARK: - SliceBackend Conformance

extension ITKSliceBackend: SliceBackend {

    /// Extract a 2D slice from the given volume using ITK.
    ///
    /// - Parameters:
    ///   - volume: Canonical engine volume (`CImageVolume`) created
    ///             from an `ITKImageDescriptor` by `ITKVolumeLoader`.
    ///   - orientation: Desired slice orientation (axial, coronal,
    ///                  sagittal, etc).
    ///   - index: Zero-based slice index in that orientation.
    ///
    /// - Returns:
    ///   A `CIImage2D` representing the extracted slice.
    ///
    /// - Note:
    ///   This placeholder implementation **always throws**
    ///   `ITKSliceBackendError.notImplemented`. Once we add the
    ///   corresponding ITK bridge entry points, this method will:
    ///
    ///   1. Validate the requested index against the volume
    ///      dimensions for the given orientation.
    ///   2. Call into ITK (via `ITKBridge`) to extract / resample
    ///      the slice.
    ///   3. Wrap the resulting buffer into a `CIImage2D` for
    ///      consumption by the rest of the engine.
    public func makeSlice(
        from volume: CImageVolume,
        orientation: SliceOrientation,
        index: Int
    ) throws -> CIImage2D {
        // Placeholder, non-lying behavior: signal that this backend
        // is not wired yet instead of returning bogus data.
        throw ITKSliceBackendError.notImplemented
    }
}
