//
//  ChromaEngine+SliceCPU.swift
//  ChromaEngineKit
//

import Foundation

// MARK: - CPU Slice Rendering

extension ChromaEngine {

    /// Extract a raw 2D slice without window/level mapping.
    public func makeRawSlice2D(
        from volume: CImageVolume,
        orientation: SliceOrientation,
        index: Int
    ) throws -> CIRawSlice2D {
        try makeSlice2DRaw(from: volume, orientation: orientation, index: index)
    }

    /// Apply window/level to a previously extracted raw slice.
    public func applyWindowLevel(
        to rawSlice: CIRawSlice2D,
        window: Float,
        level: Float
    ) -> CIImage2D {
        applyWindowLevelInternal(rawSlice: rawSlice, window: window, level: level)
    }
}

// MARK: - Private helpers

extension ChromaEngine {

    func makeSlice2DCPU(
        from volume: CImageVolume,
        orientation: SliceOrientation,
        index: Int,
        window: Float,
        level: Float
    ) throws -> CIImage2D {
        let raw = try makeSlice2DRaw(from: volume, orientation: orientation, index: index)
        return applyWindowLevelInternal(rawSlice: raw, window: window, level: level)
    }

    func makeSlice2DRaw(
        from volume: CImageVolume,
        orientation: SliceOrientation,
        index: Int
    ) throws -> CIRawSlice2D {
        let sizeX = volume.sizeX
        let sizeY = volume.sizeY
        let sizeZ = volume.sizeZ

        let clampedIndex: Int
        switch orientation {
        case .axial:
            clampedIndex = min(max(index, 0), max(sizeZ - 1, 0))
        case .coronal:
            clampedIndex = min(max(index, 0), max(sizeY - 1, 0))
        case .sagittal:
            clampedIndex = min(max(index, 0), max(sizeX - 1, 0))
        }

        let components = max(volume.componentsPerPixel, 1)
        let bytesPerPixel = components * volume.bytesPerComponent

        switch orientation {
        case .axial:
            let width = sizeX
            let height = sizeY
            let bytesPerRow = width * bytesPerPixel
            let sliceByteCount = bytesPerRow * height
            let offset = clampedIndex * sliceByteCount
            let data = volume.voxelData.subdata(in: offset..<(offset + sliceByteCount))
            return CIRawSlice2D(
                width: width,
                height: height,
                componentsPerPixel: components,
                componentType: volume.componentType,
                bytesPerComponent: volume.bytesPerComponent,
                bytesPerRow: bytesPerRow,
                orientation: orientation,
                sliceIndex: clampedIndex,
                data: data
            )
        case .coronal:
            let width = sizeX
            let height = sizeZ
            let bytesPerRow = width * bytesPerPixel
            var buffer = Data(count: bytesPerRow * height)
            buffer.withUnsafeMutableBytes { outPtr in
                guard let outBase = outPtr.baseAddress else { return }
                volume.voxelData.withUnsafeBytes { inPtr in
                    guard let inBase = inPtr.baseAddress else { return }
                    for z in 0..<sizeZ {
                        let srcOffset = ((z * sizeY + clampedIndex) * sizeX) * bytesPerPixel
                        let dstOffset = z * bytesPerRow
                        memcpy(outBase.advanced(by: dstOffset), inBase.advanced(by: srcOffset), bytesPerRow)
                    }
                }
            }
            return CIRawSlice2D(
                width: width,
                height: height,
                componentsPerPixel: components,
                componentType: volume.componentType,
                bytesPerComponent: volume.bytesPerComponent,
                bytesPerRow: bytesPerRow,
                orientation: orientation,
                sliceIndex: clampedIndex,
                data: buffer
            )
        case .sagittal:
            let width = sizeY
            let height = sizeZ
            let bytesPerRow = width * bytesPerPixel
            var buffer = Data(count: bytesPerRow * height)
            buffer.withUnsafeMutableBytes { outPtr in
                guard let outBase = outPtr.baseAddress else { return }
                volume.voxelData.withUnsafeBytes { inPtr in
                    guard let inBase = inPtr.baseAddress else { return }
                    for z in 0..<sizeZ {
                        let dstRow = outBase.advanced(by: z * bytesPerRow)
                        for y in 0..<sizeY {
                            let srcOffset = ((z * sizeY + y) * sizeX + clampedIndex) * bytesPerPixel
                            let dstOffset = y * bytesPerPixel
                            memcpy(dstRow.advanced(by: dstOffset), inBase.advanced(by: srcOffset), bytesPerPixel)
                        }
                    }
                }
            }
            return CIRawSlice2D(
                width: width,
                height: height,
                componentsPerPixel: components,
                componentType: volume.componentType,
                bytesPerComponent: volume.bytesPerComponent,
                bytesPerRow: bytesPerRow,
                orientation: orientation,
                sliceIndex: clampedIndex,
                data: buffer
            )
        }
    }

    func applyWindowLevelInternal(
        rawSlice: CIRawSlice2D,
        window: Float,
        level: Float
    ) -> CIImage2D {
        // Parity note: WW/WL operates on raw stored voxel values (no rescale slope/intercept).
        let outputCount = rawSlice.width * rawSlice.height
        var output = Data(count: outputCount)

        let lower = Double(level) - Double(window) / 2.0
        let upper = Double(level) + Double(window) / 2.0
        let range = max(upper - lower, 1.0)

        output.withUnsafeMutableBytes { outPtr in
            guard let outBytes = outPtr.bindMemory(to: UInt8.self).baseAddress else { return }
            rawSlice.data.withUnsafeBytes { inPtr in
                guard let base = inPtr.baseAddress else { return }
                for y in 0..<rawSlice.height {
                    let rowBase = base.advanced(by: y * rawSlice.bytesPerRow)
                    for x in 0..<rawSlice.width {
                        let pixelOffset = x * rawSlice.componentsPerPixel * rawSlice.bytesPerComponent
                        let value: Double
                        switch rawSlice.componentType {
                        case .uint8:
                            value = Double(rowBase.advanced(by: pixelOffset).load(as: UInt8.self))
                        case .uint16:
                            value = Double(rowBase.advanced(by: pixelOffset).load(as: UInt16.self))
                        case .int16:
                            value = Double(rowBase.advanced(by: pixelOffset).load(as: Int16.self))
                        case .float32:
                            value = Double(rowBase.advanced(by: pixelOffset).load(as: Float.self))
                        }

                        let normalized = min(max((value - lower) / range, 0.0), 1.0)
                        let outputValue = UInt8(normalized * 255.0)
                        outBytes[y * rawSlice.width + x] = outputValue
                    }
                }
            }
        }

        return CIImage2D(
            width: rawSlice.width,
            height: rawSlice.height,
            componentsPerPixel: 1,
            componentType: .uint8,
            bytesPerComponent: 1,
            bytesPerRow: rawSlice.width,
            orientation: rawSlice.orientation,
            sliceIndex: rawSlice.sliceIndex,
            data: output
        )
    }
}
