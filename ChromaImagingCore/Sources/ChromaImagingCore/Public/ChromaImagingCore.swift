// ChromaImagingCore.swift
// Public, Swifty façade for the low-level imaging core.
// This file is the main entry point the rest of the system should import.

import Foundation

/// Abstraction for image IO.
///
/// The ITK-backed implementation (`ITKImageIO`) will conform to this.
/// ChromaEngineKit can also provide alternative backends in the future.
public protocol NMImageIO: Sendable {
    /// Load a volume from one or more URLs.
    ///
    /// - For DICOM, `urls` may be:
    ///   - a directory containing a series, or
    ///   - an explicit list of file URLs for a series.
    /// - For NIfTI / NRRD, `urls` is typically a single file URL.
    func loadVolume(from urls: [URL]) async throws -> NMVolume
}

public extension NMImageIO {
    /// Convenience overload for the common single-file case.
    @inlinable
    func loadVolume(from url: URL) async throws -> NMVolume {
        try await loadVolume(from: [url])
    }
}
