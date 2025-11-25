//
//  DICOMVolumeExport.swift
//  DCMTKLoader
//
//  A Swift-friendly representation of a 3D DICOM volume.
//

import Foundation

/// Flattened z–y–x layout: index = z * (width * height) + y * width + x
public struct DICOMVolumeExport: Sendable {
    public let voxels: [Float]
    public let width: Int
    public let height: Int
    public let depth: Int
    public let spacing: (Float, Float, Float)
    public let metadata: DICOMMetadata

    public init(voxels: [Float], width: Int, height: Int, depth: Int, spacing: (Float, Float, Float), metadata: DICOMMetadata) {
        self.voxels = voxels
        self.width = width
        self.height = height
        self.depth = depth
        self.spacing = spacing
        self.metadata = metadata
    }
}
