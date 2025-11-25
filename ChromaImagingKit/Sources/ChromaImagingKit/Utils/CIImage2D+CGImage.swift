//
//  CIImage2D+CGImage.swift
//  ChromaImagingKit
//
//  Created by Mohamed Elbashir on 11/14/25.
//

import Foundation
import CoreGraphics

public extension CIImage2D {
    func makeCGImage() -> CGImage? {
        // Float [0,1] → 8-bit grayscale CGImage
        let pixelCount = width * height
        guard pixels.count == pixelCount else { return nil }

        var bytes = [UInt8](repeating: 0, count: pixelCount)
        for i in 0..<pixelCount {
            let v = max(0, min(1, pixels[i]))
            bytes[i] = UInt8((v * 255).rounded())
        }

        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitsPerComponent = 8
        let bitsPerPixel = 8
        let bytesPerPixel = 1
        let bytesPerRow = width * bytesPerPixel

        guard let data = CFDataCreate(nil, bytes, pixelCount),
              let provider = CGDataProvider(data: data) else {
            return nil
        }

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bitsPerPixel,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
