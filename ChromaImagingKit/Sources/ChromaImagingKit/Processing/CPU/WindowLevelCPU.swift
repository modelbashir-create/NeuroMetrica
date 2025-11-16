// WindowLevelCPU.swift
// ChromaImagingKit
//
// CPU-based window/level implementation using Accelerate/vDSP.
// This leverages hardware-accelerated SIMD on modern Apple CPUs.

import Foundation
import Accelerate

/// CPU-accelerated window/level operation using Accelerate.
public struct WindowLevelCPU {

    /// Applies window/level to a 2D float image.
    /// - Parameters:
    ///   - image: CIImage2D input (Float32)
    ///   - window: window width (WW)
    ///   - level: window center (WL)
    /// - Returns: new CIImage2D after WW/WL, clamped to [0, 1]
    public static func apply(
        to image: CIImage2D,
        window: Float,
        level: Float
    ) -> CIImage2D {

        let width = image.width
        let height = image.height
        let count = image.count

        let srcPixels = image.pixels
        var dstPixels = [Float](repeating: 0, count: count)

        // Compute linear transform parameters
        // norm = (pixel - (level - window/2)) / window
        // Then clamp to [0, 1].
        let slope: Float = 1.0 / window
        let intercept: Float = -((level - window / 2.0) * slope)

        // dst = slope * src + intercept  (vectorized)
        vDSP.multiply(slope, srcPixels, result: &dstPixels)
        vDSP.add(intercept, dstPixels, result: &dstPixels)

        // Clamp to [0, 1] (vectorized)
        let low: Float = 0.0
        let high: Float = 1.0
        vDSP.clip(dstPixels, to: low...high, result: &dstPixels)

        return CIImage2D(
            width: width,
            height: height,
            pixels: dstPixels,
            orientation: image.orientation
        )
    }
}
