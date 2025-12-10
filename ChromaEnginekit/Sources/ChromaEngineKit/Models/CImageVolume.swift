//
//  CImageVolume.swift
//  ChromaEngineKit
//
//  Canonical in-memory representation of a 3D/4D medical volume.
//
//  This is the single “truth” type the engine uses internally.
//  - ITKVolumeLoader converts ITKImageDescriptor → CImageVolume
//  - Backends (ITK + Native) read from CImageVolume to produce CIImage2D slices
//
//  Design goals:
//  - Independent of ITK, SwiftUI, and Core Image
//  - Swifty, value-type, Sendable
//  - Still close enough to ITK’s model (size/spacing/origin/direction)
//    that conversion is straightforward.
//

import Foundation

/// Canonical volumetric image for the engine.
///
/// Convention:
/// - Coordinate order is (x, y, z, t) where:
///   - x = left → right
///   - y = posterior → anterior (or row index)
///   - z = inferior → superior (slice index)
///   - t = time / volume index (usually 1 for static volumes)
///
/// - All units for spacing / origin are in **millimeters**, matching ITK.
/// - Direction is a row-major dim×dim matrix of direction cosines.
///
public struct CImageVolume: Sendable, Equatable {

    // MARK: - Core dimensions

    /// Image dimension (3 for standard volumes, 4 for time series).
    public let dimension: Int

    /// Voxel counts along each axis (x, y, z, t).
    ///
    /// For pure 3D volumes, `t` will typically be 1.
    public let sizeX: Int
    public let sizeY: Int
    public let sizeZ: Int
    public let sizeT: Int

    /// Physical spacing (mm) along each axis.
    ///
    /// For 3D volumes, `spacingT` is usually 1.0.
    public let spacingX: Double
    public let spacingY: Double
    public let spacingZ: Double
    public let spacingT: Double

    /// World-space origin (mm) of index (0,0,0,0).
    public let originX: Double
    public let originY: Double
    public let originZ: Double
    public let originT: Double

    /// Direction cosines as a row-major 4×4 matrix.
    ///
    /// Only the leading `dimension × dimension` block is meaningful.
    /// For 3D volumes, this is effectively a 3×3 matrix; the last row/column
    /// should be an identity extension.
    ///
    /// Example layout (row-major, 4×4):
    ///   [ r00, r01, r02, r03,
    ///     r10, r11, r12, r13,
    ///     r20, r21, r22, r23,
    ///     r30, r31, r32, r33 ]
    public let direction: [Double]

    // MARK: - Pixel format

    /// Scalar component type (uint8, uint16, int16, float32).
    public let componentType: CIPixelComponentType

    /// Number of scalar components per voxel (1 = scalar, 3 = RGB, etc.).
    public let componentsPerPixel: Int

    /// Size in bytes of a single scalar component.
    public let bytesPerComponent: Int

    /// Whether the scalar component type is signed.
    public let isSigned: Bool

    // MARK: - Storage

    /// Total number of scalar components in the volume.
    ///
    /// valueCount = sizeX * sizeY * sizeZ * sizeT * componentsPerPixel
    public let valueCount: Int

    /// Contiguous voxel buffer in ITK-like layout:
    /// x-fastest, then y, then z, then t, then component.
    ///
    /// The buffer must contain at least:
    ///   valueCount * bytesPerComponent
    /// bytes.
    public let voxelData: Data

    // MARK: - Derived properties

    /// Convenience accessors for treating this as a 3D volume.
    public var width: Int  { sizeX }
    public var height: Int { sizeY }
    public var depth: Int  { sizeZ }

    /// Total voxel count (not including components).
    public var voxelCount: Int {
        sizeX * sizeY * sizeZ * sizeT
    }

    /// Total number of bytes logically used by the volume.
    public var byteCount: Int {
        valueCount * bytesPerComponent
    }

    // MARK: - Initializer

    /// Designated initializer.
    ///
    /// - Parameters:
    ///   - dimension: Logical dimension (3 or 4).
    ///   - sizeX/sizeY/sizeZ/sizeT: Voxel counts along each axis.
    ///   - spacingX/spacingY/spacingZ/spacingT: Physical spacing (mm).
    ///   - originX/originY/originZ/originT: Origin (mm).
    ///   - direction: Row-major 4×4 direction matrix; only the leading
    ///                dim×dim block is used.
    ///   - componentType: Scalar component type.
    ///   - componentsPerPixel: Number of scalar components per voxel.
    ///   - bytesPerComponent: Size (in bytes) of one scalar component.
    ///   - isSigned: Whether the scalar component type is signed.
    ///   - voxelData: Contiguous voxel buffer.
    public init(
        dimension: Int,
        sizeX: Int,
        sizeY: Int,
        sizeZ: Int,
        sizeT: Int = 1,
        spacingX: Double,
        spacingY: Double,
        spacingZ: Double,
        spacingT: Double = 1.0,
        originX: Double,
        originY: Double,
        originZ: Double,
        originT: Double = 0.0,
        direction: [Double],
        componentType: CIPixelComponentType,
        componentsPerPixel: Int,
        bytesPerComponent: Int,
        isSigned: Bool,
        voxelData: Data
    ) {
        precondition(dimension == 3 || dimension == 4, "Only 3D/4D volumes are supported")
        precondition(sizeX > 0 && sizeY > 0 && sizeZ > 0 && sizeT > 0, "Sizes must be positive")
        precondition(componentsPerPixel > 0, "componentsPerPixel must be positive")
        precondition(bytesPerComponent > 0, "bytesPerComponent must be positive")
        precondition(direction.count == 16, "Direction must be a 4×4 row-major matrix (16 elements)")

        let voxelCount = sizeX * sizeY * sizeZ * sizeT
        let valueCount = voxelCount * componentsPerPixel
        let expectedBytes = valueCount * bytesPerComponent

        precondition(voxelData.count >= expectedBytes,
                     "voxelData is smaller than expected (\(voxelData.count) < \(expectedBytes))")

        self.dimension = dimension

        self.sizeX = sizeX
        self.sizeY = sizeY
        self.sizeZ = sizeZ
        self.sizeT = sizeT

        self.spacingX = spacingX
        self.spacingY = spacingY
        self.spacingZ = spacingZ
        self.spacingT = spacingT

        self.originX = originX
        self.originY = originY
        self.originZ = originZ
        self.originT = originT

        self.direction = direction

        self.componentType = componentType
        self.componentsPerPixel = componentsPerPixel
        self.bytesPerComponent = bytesPerComponent
        self.isSigned = isSigned

        self.valueCount = valueCount
        self.voxelData = voxelData
    }
}
