//
//  CIImage2D+Image.swift
//  NeuroMetrica
//
//  Created by Mohamed Elbashir on 11/14/25.
//

import SwiftUI
import ChromaEngineKit

extension CIImage2D {
    /// Temporary bridge from CIImage2D → CGImage.
    ///
    /// NOTE:
    /// This is a placeholder so the app compiles cleanly.
    /// Once the `CIImage2D` pixel layout is finalized in ChromaImagingCore /
    /// ChromaEngineKit, this should be updated to actually construct a
    /// `CGImage` from the underlying buffer + metadata (width, height, etc.).
    func makeCGImage() -> CGImage? {
        guard componentType == .uint8 else {
            return nil
        }

        let colorSpace: CGColorSpace
        let bitmapInfo: CGBitmapInfo

        switch componentsPerPixel {
        case 1:
            colorSpace = CGColorSpaceCreateDeviceGray()
            bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        case 4:
            colorSpace = CGColorSpaceCreateDeviceRGB()
            bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        default:
            return nil
        }

        let bitsPerComponent = bytesPerComponent * 8
        let bitsPerPixel = bitsPerComponent * componentsPerPixel

        guard let provider = CGDataProvider(data: data as CFData) else {
            return nil
        }

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bitsPerPixel,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }

    /// Convenience wrapper to get a SwiftUI Image from a CIImage2D.
    /// Assumes pixels are already window/leveled and normalized to [0, 1].
    func toSwiftUIImage() -> Image? {
        guard let cgImage = makeCGImage() else {
            return nil
        }

        return Image(decorative: cgImage, scale: 1.0, orientation: .up)
    }
}
