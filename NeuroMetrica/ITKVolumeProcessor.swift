//
//  ITKVolumeProcessor.swift
//  NeuroMetrica
//
//  Created by Mohamed Elbashir on 11/12/25.
//

import Foundation
import simd


final class ITKVolumeProcessor: VolumeProcessing {
    init() {}

    func register(
        fixed: Volume3D<Int16>,
        moving: Volume3D<Int16>
    ) throws -> Transform3D {
   
        _ = fixed
        _ = moving
        return Transform3D(matrix: matrix_identity_float4x4)
    }

    func segmentHematoma(
        in volume: Volume3D<Int16>
    ) throws -> Volume3D<UInt8> {

        let size = volume.size
        let voxelCount = size.x * size.y * size.z

        let zeros = [UInt8](repeating: 0, count: voxelCount)

        let mask = Volume3D<UInt8>(
            size: size,
            spacing: volume.spacing,
            direction: volume.direction,
            voxels: zeros
        )
        return mask
    }
}
