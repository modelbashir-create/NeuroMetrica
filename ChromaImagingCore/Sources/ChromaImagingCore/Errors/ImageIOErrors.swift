//
//  ImageIOErrors.swift
//  ChromaImagingCore
//
//  Responsibility:
//  Defines error types surfaced by the imaging core and ITK IO adapter.
//
//  Notes:
//  Error cases are part of the external contract and should remain stable.

import Foundation

/// High-level errors surfaced by the imaging core.
///
/// These are intentionally generic so that callers (NeuroMetrica app,
/// ChromaEngineKit) never have to know about ITK / GDCM / C++ details.
public enum NMImageIOError: Error, Sendable {
    /// The provided URLs were empty or invalid for the requested operation.
    case invalidInput(description: String)
    /// The underlying engine (ITK / GDCM / etc.) failed to load the volume.
    case loadFailed(description: String)
    /// The loaded volume metadata and raw buffer size do not match.
    case inconsistentData(expectedBytes: Int, actualBytes: Int)
    /// The scalar type / layout is currently unsupported by this build.
    case unsupportedFormat(description: String)
}

/// Errors specific to ITKImageIO. These will usually be wrapped
/// or mapped into higher-level engine errors (ChromaEngineError).
public enum ITKImageIOError: Error, CustomStringConvertible, LocalizedError {
    case fileNotFound(URL)
    case unsupportedPath(URL)
    case bridgeUnavailable(String)
    case loadFailed(message: String)

    public var description: String {
        switch self {
        case .fileNotFound(let url):
            return "ITKImageIO: file or directory not found at path: \(url.path)"
        case .unsupportedPath(let url):
            return "ITKImageIO: unsupported path: \(url.path)"
        case .bridgeUnavailable(let msg):
            return "ITKImageIO: bridge unavailable – \(msg)"
        case .loadFailed(let message):
            return "ITKImageIO: load failed – \(message)"
        }
    }

    public var errorDescription: String? {
        description
    }
}
