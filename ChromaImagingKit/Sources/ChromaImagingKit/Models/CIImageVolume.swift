//
//  CIImageVolume.swift
//  ChromaImagingKit
//
//  Created by Mohamed Elbashir on 11/13/25.
//

import Foundation

/// A 3D medical volume (CT/MRI).
/// Internally stored as a flattened Float32 array.
/// Supports arbitrary voxel spacing.
public struct CIImageVolume: Sendable {
    public let width: Int
    public let height: Int
    public let depth: Int

    /// Spacing between voxels in mm (x, y, z)
    public let spacing: (Float, Float, Float)

    /// The raw voxel buffer (length = width * height * depth)
    public var voxels: [Float]

    public var count: Int { width * height * depth }

    public init(
        width: Int,
        height: Int,
        depth: Int,
        spacing: (Float, Float, Float) = (1, 1, 1),
        voxels: [Float]
    ) {
        self.width = width
        self.height = height
        self.depth = depth
        self.spacing = spacing
        self.voxels = voxels
    }

    /// Access voxel by (x, y, z)
    public subscript(x: Int, y: Int, z: Int) -> Float {
        get { voxels[(z * height * width) + (y * width) + x] }
        set { voxels[(z * height * width) + (y * width) + x] = newValue }
    }

    /// Extracts one 2D slice as CIImage2D (axial)
    public func slice(at z: Int) -> CIImage2D {
        let start = z * width * height
        let end = start + (width * height)
        let slicePixels = Array(voxels[start..<end])
        return CIImage2D(width: width, height: height, pixels: slicePixels)
    }
}
