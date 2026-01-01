//
//  CIImage2D+CGImage.swift
//  ChromaEngineKit
//
//  Lightweight conversion from CIImage2D to CGImage.
//

import CoreGraphics
import Foundation

public extension CIImage2D {
    /// Convert CIImage2D to CGImage without requiring SwiftUI.
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
}
