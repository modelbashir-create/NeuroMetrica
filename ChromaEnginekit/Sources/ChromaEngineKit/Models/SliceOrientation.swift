//
//  SliceOrientation.swift
//  ChromaEngineKit
//
//  Canonical slice orientation enum shared across the engine and app.
//  This stays UI-agnostic and is safe to use from any layer that needs
//  to reason about axial / coronal / sagittal views.
//

import Foundation

/// Standard anatomical slice orientations for volumetric imaging.
///
/// This type is intentionally small and stable because many layers depend
/// on it (engine, backends, and app-level viewer state).
public enum SliceOrientation: String, CaseIterable, Sendable {
    /// Axial / transverse (feet ↔ head, looking from inferior to superior).
    case axial      = "AXIAL"
    
    /// Coronal (front ↔ back, looking from anterior to posterior).
    case coronal    = "CORONAL"
    
    /// Sagittal (left ↔ right, looking from left to right by convention).
    case sagittal   = "SAGITTAL"
}

// MARK: - Convenience

public extension SliceOrientation {
    /// Short display name suitable for UI labels or debug logs.
    var shortLabel: String {
        switch self {
        case .axial:    return "AX"
        case .coronal:  return "COR"
        case .sagittal: return "SAG"
        }
    }
    
    /// Longer human-readable description (not localized yet).
    var description: String {
        switch self {
        case .axial:    return "Axial"
        case .coronal:  return "Coronal"
        case .sagittal: return "Sagittal"
        }
    }
    
    /// Index of the primary anatomical axis in voxel coordinates.
    ///
    /// This is a *convention* used by backends that operate in simple
    /// ijk space, before any full DICOM orientation handling is added.
    ///
    /// - Returns: 0 = X, 1 = Y, 2 = Z
    var primaryAxisIndex: Int {
        switch self {
        case .axial:
            // Slices move along Z (k index).
            return 2
        case .coronal:
            // Slices move along Y (j index).
            return 1
        case .sagittal:
            // Slices move along X (i index).
            return 0
        }
    }
}
