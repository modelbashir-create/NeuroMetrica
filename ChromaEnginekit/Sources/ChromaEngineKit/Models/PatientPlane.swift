//
//  PatientPlane.swift
//  ChromaEngineKit
//
//  Patient-space slice plane definition for reslicing.
//

import Foundation
import simd

/// Patient-space plane description for oblique reslicing.
///
/// - origin: world-space coordinate (mm) of output pixel (0,0).
/// - axisU/axisV: unit vectors in patient space defining image axes.
/// - spacingU/spacingV: pixel spacing along axisU/axisV in mm.
/// - width/height: output image dimensions in pixels.
/// - orientationHint/sliceIndexHint: optional hints for downstream consumers.
public struct PatientPlane: Sendable, Equatable {
    public var origin: SIMD3<Double>
    public var axisU: SIMD3<Double>
    public var axisV: SIMD3<Double>
    public var spacingU: Double
    public var spacingV: Double
    public var width: Int
    public var height: Int
    public var orientationHint: SliceOrientation
    public var sliceIndexHint: Int

    public init(
        origin: SIMD3<Double>,
        axisU: SIMD3<Double>,
        axisV: SIMD3<Double>,
        spacingU: Double,
        spacingV: Double,
        width: Int,
        height: Int,
        orientationHint: SliceOrientation = .axial,
        sliceIndexHint: Int = 0
    ) {
        self.origin = origin
        self.axisU = axisU
        self.axisV = axisV
        self.spacingU = spacingU
        self.spacingV = spacingV
        self.width = width
        self.height = height
        self.orientationHint = orientationHint
        self.sliceIndexHint = sliceIndexHint
    }
}
