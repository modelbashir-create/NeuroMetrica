//
//  CIRawSlice2D.swift
//  ChromaEngineKit
//
//  Raw (pre-window/level) 2D slice for fast 2D rendering.
//

import Foundation

/// Raw 2D slice extracted directly from voxel data without resampling.
public struct CIRawSlice2D: Sendable, Equatable {
    public let width: Int
    public let height: Int
    public let componentsPerPixel: Int
    public let componentType: CIPixelComponentType
    public let bytesPerComponent: Int
    public let bytesPerRow: Int
    public let orientation: SliceOrientation
    public let sliceIndex: Int
    public let data: Data

    public init(
        width: Int,
        height: Int,
        componentsPerPixel: Int,
        componentType: CIPixelComponentType,
        bytesPerComponent: Int,
        bytesPerRow: Int,
        orientation: SliceOrientation,
        sliceIndex: Int,
        data: Data
    ) {
        self.width = width
        self.height = height
        self.componentsPerPixel = componentsPerPixel
        self.componentType = componentType
        self.bytesPerComponent = bytesPerComponent
        self.bytesPerRow = bytesPerRow
        self.orientation = orientation
        self.sliceIndex = sliceIndex
        self.data = data
    }
}
