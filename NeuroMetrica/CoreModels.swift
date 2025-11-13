//
//  CoreModels.swift
//  NeuroMetrica
//
//  Created by Mohamed Elbashir on 11/12/25.
//

import Foundation
import simd

// MARK: - Core volume & study models

public struct Volume3D<Pixel> {
    public let size: SIMD3<Int>      // (width, height, depth)
    public let spacing: SIMD3<Float> // in mm
    public let direction: simd_float3x3
    public let voxels: [Pixel]       // length = w*h*d

    public init(size: SIMD3<Int>,
                spacing: SIMD3<Float>,
                direction: simd_float3x3 = matrix_identity_float3x3,
                voxels: [Pixel]) {
        self.size = size
        self.spacing = spacing
        self.direction = direction
        self.voxels = voxels
    }
}

// MARK: - Transforms

/// 4x4 transform in physical (patient) space, e.g. from registration.
public struct Transform3D {
    public var matrix: simd_float4x4

    public init(matrix: simd_float4x4 = matrix_identity_float4x4) {
        self.matrix = matrix
    }
}

public enum VolumeOrientation: CaseIterable {
    case axial
    case coronal
    case sagittal
}

public struct StudySummary: Identifiable, Hashable {
    public let id: UUID
    public let patientName: String
    public let description: String
    public let date: Date
    public let modalitySummary: String
}

public struct Study: Identifiable {
    public let id: UUID
    public let summary: StudySummary
    public let series: [Series]
}

public struct Series: Identifiable {
    public let id: UUID
    public let description: String
    public let modality: String      // "CT", "MR", etc.
    public let bodyPart: String?
    public let volumes: [Volume3D<Int16>] // for now, one volume per series
}

// MARK: - Annotations / measurements

public enum Annotation: Identifiable {
    case distance(DistanceAnnotation)

    public var id: UUID {
        switch self {
        case .distance(let d): return d.id
        }
    }
}

/// Distance measurement on a single slice, 
public struct DistanceAnnotation: Identifiable {
    public let id: UUID
    public var sliceIndex: Int
    public var orientation: VolumeOrientation
    public var p1: SIMD2<Float> // normalized (0..1, 0..1)
    public var p2: SIMD2<Float>
    public var lengthMm: Float? // optional; we’ll compute later using spacing

    public init(sliceIndex: Int,
                orientation: VolumeOrientation,
                p1: SIMD2<Float>,
                p2: SIMD2<Float>,
                lengthMm: Float? = nil) {
        self.id = UUID()
        self.sliceIndex = sliceIndex
        self.orientation = orientation
        self.p1 = p1
        self.p2 = p2
        self.lengthMm = lengthMm
    }
}
