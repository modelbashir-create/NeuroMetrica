
//
//  BackendProtocols.swift
//  ChromaEngineKit
//
//  Canonical processing backend interfaces used by ChromaEngine.
//
//  Design:
//  - SliceBackend        → extracts 2D slices from CImageVolume
//  - WindowLevelBackend  → applies WW/WL to a slice
//  - ChromaProcessingBackend
//        • façade the app / ChromaEngine sees
//        • owns a SliceBackend + WindowLevelBackend
//

import Foundation
import ChromaImagingCore

// MARK: - Slice Backend

/// Extracts 2D slices from the canonical engine volume type.
public protocol SliceBackend: Sendable {

    /// Extract a slice in the given orientation at the given index.
    ///
    /// - Parameters:
    ///   - volume:      Canonical volume (already loaded via ITK).
    ///   - orientation: Axial / coronal / sagittal.
    ///   - index:       Zero-based slice index.
    ///
    /// - Returns: A `CIImage2D` suitable for display or further
    ///            processing (e.g. WW/WL).
    func makeSlice(
        from volume: CImageVolume,
        orientation: SliceOrientation,
        index: Int
    ) throws -> CIImage2D
}

// MARK: - Window / Level Backend

/// Applies window/level and related display-time processing.
public protocol WindowLevelBackend: Sendable {

    /// Produce a window/leveled slice for display.
    ///
    /// Implementations are free to:
    /// - Reuse a cached raw slice
    /// - Re-run slice extraction internally
    /// - Use CPU (vDSP) or GPU (Metal) under the hood
    func makeWindowLeveledSlice(
        from volume: CImageVolume,
        orientation: SliceOrientation,
        sliceIndex: Int,
        window: Float,
        level: Float
    ) throws -> CIImage2D
}

// MARK: - Composite Backend (what ChromaEngine sees)

/// High-level processing backend used by `ChromaEngine`.
///
/// This is the only type the app / bridge needs to know about.
/// Internally it is composed of:
/// - a `SliceBackend` and
/// - a `WindowLevelBackend`
public protocol ChromaProcessingBackend: Sendable {

    /// Backend responsible for raw slice extraction.
    var sliceBackend: any SliceBackend { get }

    /// Backend responsible for WW/WL processing.
    var windowLevelBackend: any WindowLevelBackend { get }

    /// Convenience façade to produce a window/leveled slice.
    ///
    /// Default implementation is provided below: it simply delegates
    /// to `windowLevelBackend`. Backends can override if they want
    /// to do something more clever.
    func makeWindowLeveledSlice(
        from volume: CImageVolume,
        orientation: SliceOrientation,
        sliceIndex: Int,
        window: Float,
        level: Float
    ) throws -> CIImage2D
}

// Default delegation to the underlying WindowLevelBackend.
public extension ChromaProcessingBackend {
    func makeWindowLeveledSlice(
        from volume: CImageVolume,
        orientation: SliceOrientation,
        sliceIndex: Int,
        window: Float,
        level: Float
    ) throws -> CIImage2D {
        try windowLevelBackend.makeWindowLeveledSlice(
            from: volume,
            orientation: orientation,
            sliceIndex: sliceIndex,
            window: window,
            level: level
        )
    }
}

// MARK: - Simple default composite backend (optional but handy)

/// A basic concrete backend that just wraps separate slice and
/// window/level backends. This makes it easy for the app to build
/// a "default" backend.
///
/// Example:
///   let backend = DefaultProcessingBackend(
///       sliceBackend: ITKSliceBackend(),
///       windowLevelBackend: ITKWindowLevelBackend()
///   )
///   let engine = ChromaEngine(backend: backend)
public struct DefaultProcessingBackend: ChromaProcessingBackend {

    public let sliceBackend: any SliceBackend
    public let windowLevelBackend: any WindowLevelBackend

    public init(
        sliceBackend: any SliceBackend,
        windowLevelBackend: any WindowLevelBackend
    ) {
        self.sliceBackend = sliceBackend
        self.windowLevelBackend = windowLevelBackend
    }
}
