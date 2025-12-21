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
        // TODO: Implement real conversion from CIImage2D → CGImage
        return nil
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
