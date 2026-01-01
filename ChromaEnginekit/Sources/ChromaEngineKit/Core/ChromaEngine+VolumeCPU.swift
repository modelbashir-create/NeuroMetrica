//
//  ChromaEngine+VolumeCPU.swift
//  ChromaEngineKit
//

import Foundation

// MARK: - CPU Volume Rendering

extension ChromaEngine {

    func makeVolumeRenderCPU(
        from volume: CImageVolume,
        orientation: SliceOrientation,
        window: Float,
        level: Float,
        step: Float
    ) throws -> CIImage2D {
        guard volume.componentsPerPixel == 1 else {
            throw MetalSliceRendererError.unsupportedComponentsPerPixel
        }

        let sizeX = volume.sizeX
        let sizeY = volume.sizeY
        let sizeZ = volume.sizeZ
        let outputDims: (width: Int, height: Int)
        let depth: Int

        switch orientation {
        case .axial:
            outputDims = (width: sizeX, height: sizeY)
            depth = sizeZ
        case .coronal:
            outputDims = (width: sizeX, height: sizeZ)
            depth = sizeY
        case .sagittal:
            outputDims = (width: sizeY, height: sizeZ)
            depth = sizeX
        }

        let outputCount = outputDims.width * outputDims.height
        var output = Data(count: outputCount)
        let bytesPerVoxel = volume.bytesPerComponent * volume.componentsPerPixel
        let safeStep = max(step, 1.0)

        let lower = Double(level) - Double(window) / 2.0
        let upper = Double(level) + Double(window) / 2.0
        let range = max(upper - lower, 1.0)

        output.withUnsafeMutableBytes { outPtr in
            guard let outBytes = outPtr.bindMemory(to: UInt8.self).baseAddress else { return }
            volume.voxelData.withUnsafeBytes { inPtr in
                guard let inBase = inPtr.baseAddress else { return }
                for y in 0..<outputDims.height {
                    for x in 0..<outputDims.width {
                        var accum = 0.0
                        var pos = 0.0
                        while pos < Double(depth) {
                            let idx = min(Int(pos), max(depth - 1, 0))
                            let voxelIndex: Int
                            switch orientation {
                            case .axial:
                                voxelIndex = (idx * sizeX * sizeY) + (y * sizeX) + x
                            case .coronal:
                                voxelIndex = (y * sizeX * sizeY) + (idx * sizeX) + x
                            case .sagittal:
                                voxelIndex = (y * sizeX * sizeY) + (x * sizeX) + idx
                            }
                            let byteOffset = voxelIndex * bytesPerVoxel
                            let value: Double
                            switch volume.componentType {
                            case .uint8:
                                value = Double(inBase.advanced(by: byteOffset).load(as: UInt8.self))
                            case .uint16:
                                value = Double(inBase.advanced(by: byteOffset).load(as: UInt16.self))
                            case .int16:
                                value = Double(inBase.advanced(by: byteOffset).load(as: Int16.self))
                            case .float32:
                                value = Double(inBase.advanced(by: byteOffset).load(as: Float.self))
                            }
                            let normalized = min(max((value - lower) / range, 0.0), 1.0)
                            accum = accum + (1.0 - accum) * normalized
                            if accum >= 0.999 {
                                break
                            }
                            pos += Double(safeStep)
                        }
                        outBytes[y * outputDims.width + x] = UInt8(accum * 255.0)
                    }
                }
            }
        }

        return CIImage2D(
            width: outputDims.width,
            height: outputDims.height,
            componentsPerPixel: 1,
            componentType: .uint8,
            bytesPerComponent: 1,
            bytesPerRow: outputDims.width,
            orientation: orientation,
            sliceIndex: 0,
            data: output
        )
    }
}
