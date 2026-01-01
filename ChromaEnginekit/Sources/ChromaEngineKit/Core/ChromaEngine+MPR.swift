//
//  ChromaEngine+MPR.swift
//  ChromaEngineKit
//

import Foundation
import simd

// MARK: - MPR

extension ChromaEngine {

    /// Extract an oblique slice defined in patient space.
    ///
    /// This uses the same reslicing path as standard axial/coronal/sagittal
    /// but allows arbitrary plane orientation.
    public func makeSlice(
        from volume: CImageVolume,
        plane: PatientPlane,
        window: Float,
        level: Float
    ) async throws -> CIImage2D {
        try makeSliceMPR(
            volume: volume,
            plane: plane,
            window: window,
            level: level
        )
    }
}

// MARK: - Private helpers

private extension ChromaEngine {

    func makeSliceMPR(
        volume: CImageVolume,
        plane: PatientPlane,
        window: Float,
        level: Float
    ) throws -> CIImage2D {
        let outputCount = plane.width * plane.height
        var output = Data(count: outputCount)

        let lower = Double(level) - Double(window) / 2.0
        let upper = Double(level) + Double(window) / 2.0
        let range = max(upper - lower, 1.0)

        output.withUnsafeMutableBytes { outPtr in
            guard let outBytes = outPtr.bindMemory(to: UInt8.self).baseAddress else { return }

            volume.voxelData.withUnsafeBytes { inPtr in
                guard let base = inPtr.baseAddress else { return }
                for y in 0..<plane.height {
                    for x in 0..<plane.width {
                        let patientPoint = plane.origin
                            + plane.axisU * (Double(x) * plane.spacingU)
                            + plane.axisV * (Double(y) * plane.spacingV)

                        guard let continuousIndex = patientToVoxelIndex(volume: volume, point: patientPoint) else {
                            outBytes[y * plane.width + x] = 0
                            continue
                        }

                        let sample = sampleTrilinear(
                            base: base,
                            volume: volume,
                            index: continuousIndex
                        )

                        let normalized = min(max((sample - lower) / range, 0.0), 1.0)
                        let outputValue = UInt8(normalized * 255.0)
                        outBytes[y * plane.width + x] = outputValue
                    }
                }
            }
        }

        return CIImage2D(
            width: plane.width,
            height: plane.height,
            componentsPerPixel: 1,
            componentType: .uint8,
            bytesPerComponent: 1,
            bytesPerRow: plane.width,
            orientation: plane.orientationHint,
            sliceIndex: plane.sliceIndexHint,
            data: output
        )
    }

    func planeForOrientation(
        volume: CImageVolume,
        orientation: SliceOrientation,
        sliceIndex: Int,
        width: Int,
        height: Int
    ) -> PatientPlane {
        let direction = directionColumns(volume: volume)
        let axisX = direction.x
        let axisY = direction.y
        let axisZ = direction.z

        let origin: SIMD3<Double>
        let axisU: SIMD3<Double>
        let axisV: SIMD3<Double>
        let spacingU: Double
        let spacingV: Double

        switch orientation {
        case .axial:
            origin = voxelToPatient(volume: volume, index: SIMD3<Double>(0, 0, Double(sliceIndex)))
            axisU = axisX
            axisV = axisY
            spacingU = volume.spacingX
            spacingV = volume.spacingY
        case .coronal:
            origin = voxelToPatient(volume: volume, index: SIMD3<Double>(0, Double(sliceIndex), 0))
            axisU = axisX
            axisV = axisZ
            spacingU = volume.spacingX
            spacingV = volume.spacingZ
        case .sagittal:
            origin = voxelToPatient(volume: volume, index: SIMD3<Double>(Double(sliceIndex), 0, 0))
            axisU = axisY
            axisV = axisZ
            spacingU = volume.spacingY
            spacingV = volume.spacingZ
        }

        return PatientPlane(
            origin: origin,
            axisU: axisU,
            axisV: axisV,
            spacingU: spacingU,
            spacingV: spacingV,
            width: width,
            height: height,
            orientationHint: orientation,
            sliceIndexHint: sliceIndex
        )
    }

    func patientToVoxelIndex(volume: CImageVolume, point: SIMD3<Double>) -> SIMD3<Double>? {
        let dir = directionMatrix(volume: volume)
        guard let inv = invert3x3(dir) else {
            return nil
        }
        let origin = SIMD3<Double>(volume.originX, volume.originY, volume.originZ)
        let relative = point - origin
        let indexContinuous = multiply(inv, relative)
        return SIMD3<Double>(
            indexContinuous.x / volume.spacingX,
            indexContinuous.y / volume.spacingY,
            indexContinuous.z / volume.spacingZ
        )
    }

    func voxelToPatient(volume: CImageVolume, index: SIMD3<Double>) -> SIMD3<Double> {
        let dir = directionMatrix(volume: volume)
        let scaled = SIMD3<Double>(
            index.x * volume.spacingX,
            index.y * volume.spacingY,
            index.z * volume.spacingZ
        )
        let rotated = multiply(dir, scaled)
        let origin = SIMD3<Double>(volume.originX, volume.originY, volume.originZ)
        return origin + rotated
    }

    func sampleTrilinear(
        base: UnsafeRawPointer,
        volume: CImageVolume,
        index: SIMD3<Double>
    ) -> Double {
        let x = index.x
        let y = index.y
        let z = index.z

        let x0 = Int(floor(x))
        let y0 = Int(floor(y))
        let z0 = Int(floor(z))
        let x1 = x0 + 1
        let y1 = y0 + 1
        let z1 = z0 + 1

        if x0 < 0 || y0 < 0 || z0 < 0 ||
            x1 >= volume.sizeX || y1 >= volume.sizeY || z1 >= volume.sizeZ {
            return 0.0
        }

        let xd = x - Double(x0)
        let yd = y - Double(y0)
        let zd = z - Double(z0)

        let c000 = voxelValue(base: base, volume: volume, i: x0, j: y0, k: z0)
        let c100 = voxelValue(base: base, volume: volume, i: x1, j: y0, k: z0)
        let c010 = voxelValue(base: base, volume: volume, i: x0, j: y1, k: z0)
        let c110 = voxelValue(base: base, volume: volume, i: x1, j: y1, k: z0)
        let c001 = voxelValue(base: base, volume: volume, i: x0, j: y0, k: z1)
        let c101 = voxelValue(base: base, volume: volume, i: x1, j: y0, k: z1)
        let c011 = voxelValue(base: base, volume: volume, i: x0, j: y1, k: z1)
        let c111 = voxelValue(base: base, volume: volume, i: x1, j: y1, k: z1)

        let c00 = c000 * (1 - xd) + c100 * xd
        let c10 = c010 * (1 - xd) + c110 * xd
        let c01 = c001 * (1 - xd) + c101 * xd
        let c11 = c011 * (1 - xd) + c111 * xd

        let c0 = c00 * (1 - yd) + c10 * yd
        let c1 = c01 * (1 - yd) + c11 * yd

        return c0 * (1 - zd) + c1 * zd
    }

    func voxelValue(
        base: UnsafeRawPointer,
        volume: CImageVolume,
        i: Int,
        j: Int,
        k: Int
    ) -> Double {
        let components = max(volume.componentsPerPixel, 1)
        let voxelIndex = ((k * volume.sizeY + j) * volume.sizeX + i) * components
        let byteOffset = voxelIndex * volume.bytesPerComponent
        switch volume.componentType {
        case .uint8:
            return Double(base.advanced(by: byteOffset).load(as: UInt8.self))
        case .uint16:
            return Double(base.advanced(by: byteOffset).load(as: UInt16.self))
        case .int16:
            return Double(base.advanced(by: byteOffset).load(as: Int16.self))
        case .float32:
            return Double(base.advanced(by: byteOffset).load(as: Float.self))
        }
    }
}
