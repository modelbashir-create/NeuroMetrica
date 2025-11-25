//
//  SliceOrientation.swift
//  ChromaImagingKit
//
//  Created by Mohamed Elbashir on 11/14/25.
//


// SliceOrientation.swift
// ChromaImagingKit

import Foundation

/// Standard anatomical orientation of a 2D slice.
public enum SliceOrientation: String, Sendable {
    /// Axial (transverse) plane: slices along the superior–inferior axis.
    case axial
    /// Coronal plane: slices along the anterior–posterior axis.
    case coronal
    /// Sagittal plane: slices along the left–right axis.
    case sagittal
}