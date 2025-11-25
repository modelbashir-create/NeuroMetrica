//
//  CIImage2D.swift
//  ChromaImagingKit
//
//  Created by Mohamed Elbashir on 11/13/25.
//

import Foundation

/// A simple, fast, Swift-native 2D image buffer.
/// Supports Float32 pixels (common in medical imaging).
public struct CIImage2D: Sendable {
    public let width: Int
    public let height: Int
    public var pixels: [Float]   // row-major: y * width + x

    /// Optional anatomical orientation of this 2D slice (axial/coronal/sagittal).
    public var orientation: SliceOrientation?

    public var count: Int { width * height }

    public init(
        width: Int,
        height: Int,
        pixels: [Float],
        orientation: SliceOrientation? = nil
    ) {
        self.width = width
        self.height = height
        self.pixels = pixels
        self.orientation = orientation
    }

    public subscript(x: Int, y: Int) -> Float {
        get { pixels[y * width + x] }
        set { pixels[y * width + x] = newValue }
    }
}
