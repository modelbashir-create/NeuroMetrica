//
//  ITKWindowLevelBackend.swift
//  ChromaEngineKit
//
//  ITK-backed implementation of WindowLevelBackend.
//
//  For now this is a placeholder that always throws `notImplemented`,
//  but the public surface is correct and stable and matches the
//  `WindowLevelBackend` protocol.
//

import Foundation
import ChromaImagingCore

// MARK: - Error Type

public enum ITKWindowLevelBackendError: Error {
    /// Placeholder: ITK WW/WL processing is not wired up yet.
    case notImplemented
}

// MARK: - Backend Type

/// ITK-backed window/level processing backend.
///
/// In the future this type will:
/// - Take a raw slice (or extract one internally) from `CImageVolume`.
/// - Apply window/level using ITK / native numerics as needed.
/// - Return a `CIImage2D` ready for display.
public final class ITKWindowLevelBackend: Sendable {
    public init() {}
}

// MARK: - WindowLevelBackend Conformance

extension ITKWindowLevelBackend: WindowLevelBackend {

    /// Produce a window/leveled slice for display using ITK-backed logic.
    ///
    /// - Parameters:
    ///   - volume:      Canonical volume (`CImageVolume`) already
    ///                  loaded via the ITK-based IO stack.
    ///   - orientation: Axial / coronal / sagittal, etc.
    ///   - sliceIndex:  Zero-based slice index in that orientation.
    ///   - window:      Window width (WW).
    ///   - level:       Window level (WL).
    ///
    /// - Returns: A `CIImage2D` that the app can convert to CGImage /
    ///            SwiftUI `Image` in the viewer.
    ///
    /// - Note:
    ///   This placeholder implementation **always throws**
    ///   `ITKWindowLevelBackendError.notImplemented`. Once we wire up
    ///   the real processing path, this will:
    ///
    ///   1. Obtain (or reuse) a raw slice buffer for the requested
    ///      orientation and index.
    ///   2. Apply WW/WL and any intensity scaling.
    ///   3. Wrap the result into `CIImage2D`.
    public func makeWindowLeveledSlice(
        from volume: CImageVolume,
        orientation: SliceOrientation,
        sliceIndex: Int,
        window: Float,
        level: Float
    ) throws -> CIImage2D {
        throw ITKWindowLevelBackendError.notImplemented
    }
}
