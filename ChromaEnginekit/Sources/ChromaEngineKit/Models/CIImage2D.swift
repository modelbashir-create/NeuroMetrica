//
//  CIImage2D.swift
//  ChromaEngineKit
//
//  Engine-level representation of a single 2D slice.
//
//  This type is independent of ITK, SwiftUI, and Core Image. It is a
//  simple, canonical container that backends can fill and the app can
//  convert into CGImage / SwiftUI.Image via CIImage2D+Image.swift.
//

import Foundation

/// Scalar component type for engine slices.
///
/// This is intentionally small and Swifty; it does **not** try to cover
/// every ITK pixel type. The ITK bridge is responsible for mapping its
/// rich IO types into one of these canonical formats.
public enum CIPixelComponentType: String, Codable, Sendable {
    case uint8
    case uint16
    case int16
    case float32
}

/// 2D image slice extracted from a `CImageVolume`.
///
/// Layout guarantees:
/// - Row-major, top-left origin (y increases downward, x to the right).
/// - Pixels are tightly packed per row; `bytesPerRow` describes the row stride.
/// - Buffer is immutable from the engine perspective (`Data`).
///
/// Higher-level code (CIImage2D+Image.swift) is responsible for
/// interpreting this buffer and turning it into CGImage / SwiftUI.Image.
public struct CIImage2D: Sendable, Equatable {

    // MARK: - Core dimensions

    /// Width in pixels.
    public let width: Int

    /// Height in pixels.
    public let height: Int

    /// Number of scalar components per pixel (1 = grayscale, 3 = RGB, 4 = RGBA).
    public let componentsPerPixel: Int

    /// Scalar component type.
    public let componentType: CIPixelComponentType

    /// Number of bytes in a single scalar component.
    public let bytesPerComponent: Int

    /// Number of bytes from the start of one row to the start of the next.
    ///
    /// Usually `width * componentsPerPixel * bytesPerComponent`, but a
    /// backend is allowed to pad to a larger stride if needed.
    public let bytesPerRow: Int

    // MARK: - Slice context

    /// Logical orientation of this slice (axial / coronal / sagittal).
    public let orientation: SliceOrientation

    /// Index of this slice in the chosen orientation.
    public let sliceIndex: Int

    // MARK: - Pixel data

    /// Immutable contiguous pixel buffer.
    ///
    /// Layout: row-major, top-left origin.
    /// Size: at least `bytesPerRow * height` bytes.
    public let data: Data

    // MARK: - Derived properties

    /// Total number of pixels.
    public var pixelCount: Int {
        width * height
    }

    /// Total number of scalar components.
    public var componentCount: Int {
        pixelCount * componentsPerPixel
    }

    /// Total number of bytes logically used by pixels
    /// (not necessarily equal to `data.count` if rows are padded).
    public var logicalByteCount: Int {
        bytesPerRow * height
    }

    // MARK: - Init

    /// Designated initializer.
    ///
    /// - Parameters:
    ///   - width: Image width in pixels.
    ///   - height: Image height in pixels.
    ///   - componentsPerPixel: Number of scalar components per pixel.
    ///   - componentType: Scalar component type.
    ///   - bytesPerComponent: Size in bytes of one scalar component.
    ///   - bytesPerRow: Stride in bytes between consecutive rows.
    ///   - orientation: Logical slice orientation.
    ///   - sliceIndex: Index of this slice in that orientation.
    ///   - data: Immutable buffer containing the pixel bytes.
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
