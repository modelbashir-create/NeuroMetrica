//
//  CIImage2D+Image.swift
//  NeuroMetrica
//
//  Created by Mohamed Elbashir on 11/14/25.
//

import SwiftUI
import ChromaEngineKit

extension CIImage2D {
    /// Convenience wrapper to get a SwiftUI Image from a CIImage2D.
    /// Assumes pixels are already window/leveled and normalized to [0, 1].
    func toSwiftUIImage() -> Image? {
        guard let cgImage = makeCGImage() else {
            return nil
        }

        return Image(decorative: cgImage, scale: 1.0, orientation: .up)
    }
}
