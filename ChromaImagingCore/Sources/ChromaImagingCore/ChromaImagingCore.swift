// ChromaImagingCore.swift
// Public, Swifty façade for the low-level imaging core.
// This file is the main entry point the rest of the system should import.

import Foundation

// MARK: - Core Error Types

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


// MARK: - Scalar Types

/// Scalar types supported by the imaging core.
///
/// We can expand this later as needed (e.g. 8-bit, 32-bit int, etc.).
public enum NMScalarType: Sendable {
    case int16
    case uint16
    case float32
    case float64

    /// Number of bytes per scalar component.
    public var bytesPerComponent: Int {
        switch self {
        case .int16, .uint16:
            return 2
        case .float32:
            return 4
        case .float64:
            return 8
        }
    }
}


// MARK: - Canonical Volume Type

/// Core neutral volume type used across NeuroMetrica.
///
/// All engines (ITK, native Metal path, etc.) should produce and consume
/// this type. The UI and higher-level logic never see C++/ITK types directly.
public struct NMVolume: Sendable {
    /// Dimensions in voxels. `t` is for time / volume index; for most
    /// static clinical scans this will be 1.
    public var dimensions: (x: Int, y: Int, z: Int, t: Int)

    /// Physical spacing between voxels (in mm) along each axis.
    public var spacing: (x: Double, y: Double, z: Double)

    /// Physical origin (in mm) in patient / scanner space.
    public var origin: (x: Double, y: Double, z: Double)

    /// 3×3 direction cosines matrix in row-major order.
    /// Must contain exactly 9 elements.
    public var direction: [Double]

    /// Scalar type for this volume (int16, float32, etc.).
    public var scalarType: NMScalarType

    /// Raw voxel buffer. Layout and interpretation depends on `scalarType`.
    ///
    /// For now we assume:
    ///   - single component per voxel (no vector pixels),
    ///   - contiguous storage: (((t, z, y, x))).
    public var data: Data

    // MARK: Derived properties

    /// Total number of voxels (x * y * z * t).
    public var voxelCount: Int {
        max(0, dimensions.x)
        * max(0, dimensions.y)
        * max(0, dimensions.z)
        * max(1, dimensions.t)
    }

    /// Number of scalar components per voxel.
    /// We keep this as `1` for now; if we add RGB / vectors later
    /// this becomes part of the descriptor.
    public var componentsPerVoxel: Int { 1 }

    /// Expected number of bytes in `data` based on dimensions + scalarType.
    public var expectedDataLength: Int {
        voxelCount * componentsPerVoxel * scalarType.bytesPerComponent
    }

    // MARK: Init

    /// Designated initializer with optional consistency check.
    ///
    /// - Parameters:
    ///   - validateDataSize: when `true`, will throw if `data.count`
    ///     does not match the expected size from dimensions + scalarType.
    public init(
        dimensions: (x: Int, y: Int, z: Int, t: Int),
        spacing: (x: Double, y: Double, z: Double),
        origin: (x: Double, y: Double, z: Double),
        direction: [Double],
        scalarType: NMScalarType,
        data: Data,
        validateDataSize: Bool = true
    ) throws {
        precondition(direction.count == 9, "direction must be a 3×3 matrix (9 elements)")

        self.dimensions = dimensions
        self.spacing = spacing
        self.origin = origin
        self.direction = direction
        self.scalarType = scalarType
        self.data = data

        if validateDataSize {
            let expected = expectedDataLength
            if data.count != expected {
                throw NMImageIOError.inconsistentData(
                    expectedBytes: expected,
                    actualBytes: data.count
                )
            }
        }
    }
}


// MARK: - Image IO Abstraction

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
