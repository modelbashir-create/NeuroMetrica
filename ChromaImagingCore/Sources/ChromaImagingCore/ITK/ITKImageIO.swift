//
//  ITKImageIO.swift
//  ChromaImagingCore
//
//  Swift façade around the ITK bridge for volume loading.
//  This is the ONLY entry point higher layers should use
//  to read DICOM / NIfTI / NRRD volumes via ITK.
//

import Foundation
import ITKBridge   // SwiftPM module created by the ITKBridge target

// MARK: - High-level format hint

/// High-level format hint for ITK volume loading.
public enum ITKVolumeFormatHint {
    /// Let ITKImageIO decide (directory → DICOM series, file → single-volume).
    case auto

    /// Treat the URL as a DICOM series directory.
    case dicomSeries

    /// Treat the URL as a single-file volume (NIfTI, NRRD, etc.).
    case singleFile
}

/// DICOM backend preference for ITK.
public enum ITKDicomBackend {
    /// Prefer DCMTK, fall back to GDCM if unavailable.
    case dcmtk
    /// Force GDCM.
    case gdcm
    /// Auto-select (DCMTK when available).
    case automatic
}

// MARK: - Main façade

/// Main entry point for ITK-based volume loading.
///
/// Higher layers (ChromaEngineKit) call this to ask ITK to read a volume.
/// This implementation calls into the ObjC++ bridge (`ITKBridge.h` / `ITKBridge.mm`)
/// and converts the returned C descriptor into a Swift `ITKImageDescriptor`.
///
/// Supported scenarios:
/// - DICOM series directory (GDCM/DCMTK via ITK)
/// - Single-file volumes (e.g. `.nii`, `.nii.gz`, `.nrrd`)
public enum ITKImageIO {

    /// Load a volume at the given URL using ITK.
    ///
    /// - Parameters:
    ///   - url: Path to a directory (DICOM series) or single volume file.
    ///   - formatHint: Optional hint to force DICOM vs single-file behavior.
    /// - Returns: An `ITKImageDescriptor` describing the loaded volume.
    public static func loadVolume(
        at url: URL,
        formatHint: ITKVolumeFormatHint = .auto,
        dicomBackend: ITKDicomBackend = .automatic
    ) throws -> ITKImageDescriptor {

        let fm = FileManager.default
        let path = url.path

        guard fm.fileExists(atPath: path) else {
            throw ITKImageIOError.fileNotFound(url)
        }

        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false

        let resolvedFormat: ITKVolumeFormatHint
        switch formatHint {
        case .auto:
            resolvedFormat = isDirectory ? .dicomSeries : .singleFile
        default:
            resolvedFormat = formatHint
        }

        switch resolvedFormat {
        case .dicomSeries:
            return try loadDicomSeries(at: url, backend: dicomBackend)
        case .singleFile:
            return try loadSingleFileVolume(at: url, backend: dicomBackend)
        case .auto:
            // Should never happen because we resolved above.
            throw ITKImageIOError.unsupportedPath(url)
        }
    }

    // MARK: - Private helpers

    /// Load a DICOM series volume from a directory via ITKBridge.
    private static func loadDicomSeries(
        at url: URL,
        backend: ITKDicomBackend
    ) throws -> ITKImageDescriptor {
        var cDescriptor = ITKImageDescriptorC()
        var errorBuffer = [CChar](repeating: 0, count: 1024)

        let resolvedBackend = resolveBackend(backend)
        let success = pathString(for: url).withCString { cPath in
            errorBuffer.withUnsafeMutableBufferPointer { errPtr in
                ITKLoadDicomSeriesWithBackend(
                    cPath,
                    resolvedBackend,
                    &cDescriptor,
                    errPtr.baseAddress,
                    Int32(errPtr.count)   // <- Int → Int32
                )
            }
        }

        guard success else {
            let rawMessage = String(cString: errorBuffer)
            let message = rawMessage.isEmpty ? "Unknown ITK error." : rawMessage
            throw ITKImageIOError.loadFailed(message: message)
        }

        return ITKImageDescriptor(cDescriptor: cDescriptor)
    }

    /// Load a single-file volume (NIfTI, NRRD, etc.) via ITKBridge.
    private static func loadSingleFileVolume(
        at url: URL,
        backend: ITKDicomBackend
    ) throws -> ITKImageDescriptor {
        var cDescriptor = ITKImageDescriptorC()
        var errorBuffer = [CChar](repeating: 0, count: 1024)

        let path = pathString(for: url)
        let ext = url.pathExtension.lowercased()
        let isDicomFile = ext == "dcm"

        let success = path.withCString { cPath in
            errorBuffer.withUnsafeMutableBufferPointer { errPtr in
                if isDicomFile {
                    let resolvedBackend = resolveBackend(backend)
                    return ITKLoadDicomFileWithBackend(
                        cPath,
                        resolvedBackend,
                        &cDescriptor,
                        errPtr.baseAddress,
                        Int32(errPtr.count)   // <- Int → Int32
                    )
                }

                return ITKLoadSingleFileVolume(
                    cPath,
                    &cDescriptor,
                    errPtr.baseAddress,
                    Int32(errPtr.count)   // <- Int → Int32
                )
            }
        }

        guard success else {
            let rawMessage = String(cString: errorBuffer)
            let message = rawMessage.isEmpty ? "Unknown ITK error." : rawMessage
            throw ITKImageIOError.loadFailed(message: message)
        }

        return ITKImageDescriptor(cDescriptor: cDescriptor)
    }

    // MARK: - Path utilities

    /// Normalize the URL into a file-system path string that is safe to
    /// hand to the C bridge. On Apple platforms this is usually just
    /// `url.path`, but we keep this helper for future flexibility.
    private static func pathString(for url: URL) -> String {
        // If you later want to support security-scoped bookmarks, sandboxing,
        // etc., this is where you adapt the URL before calling into C.
        return url.path
    }

    private static func resolveBackend(_ backend: ITKDicomBackend) -> ITKDicomBackendC {
        switch backend {
        case .dcmtk:
            return ITKBridgeSupportsDCMTK() ? ITKDicomBackend_DCMTK : ITKDicomBackend_GDCM
        case .gdcm:
            return ITKDicomBackend_GDCM
        case .automatic:
            return ITKBridgeSupportsDCMTK() ? ITKDicomBackend_DCMTK : ITKDicomBackend_GDCM
        }
    }
}
