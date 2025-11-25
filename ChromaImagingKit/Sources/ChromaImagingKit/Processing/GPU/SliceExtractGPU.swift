// SliceExtractGPU.swift
// ChromaImagingKit

import Foundation
import Metal

/// GPU-accelerated slice extraction from a 3D volume.
public struct SliceExtractGPU {

    // MARK: - Pipeline States

    private static let axialPipeline: MTLComputePipelineState = {
        let context = ChromaContext.shared
        guard let function = context.library.makeFunction(name: "axialSliceKernel") else {
            fatalError("❌ Failed to find 'axialSliceKernel' in Metal library.")
        }
        do {
            return try context.device.makeComputePipelineState(function: function)
        } catch {
            fatalError("❌ Failed to create pipeline state for axialSliceKernel: \(error)")
        }
    }()

    private static let coronalPipeline: MTLComputePipelineState = {
        let context = ChromaContext.shared
        guard let function = context.library.makeFunction(name: "coronalSliceKernel") else {
            fatalError("❌ Failed to find 'coronalSliceKernel' in Metal library.")
        }
        do {
            return try context.device.makeComputePipelineState(function: function)
        } catch {
            fatalError("❌ Failed to create pipeline state for coronalSliceKernel: \(error)")
        }
    }()

    private static let sagittalPipeline: MTLComputePipelineState = {
        let context = ChromaContext.shared
        guard let function = context.library.makeFunction(name: "sagittalSliceKernel") else {
            fatalError("❌ Failed to find 'sagittalSliceKernel' in Metal library.")
        }
        do {
            return try context.device.makeComputePipelineState(function: function)
        } catch {
            fatalError("❌ Failed to create pipeline state for sagittalSliceKernel: \(error)")
        }
    }()

    // MARK: - Public API

    /// Axial slice: z-plane, size = width x height (x, y)
    public static func axialSlice(from volume: CIImageVolume, z: Int) throws -> CIImage2D {
        guard z >= 0 && z < volume.depth else {
            throw SliceExtractError.invalidIndex
        }
        let context = ChromaContext.shared
        let device = context.device
        let commandBuffer = context.makeCommandBuffer()

        let width = volume.width
        let height = volume.height
        let depth = volume.depth
        let slicePixelCount = width * height

        let volumeBuffer = context.makeBuffer(from: volume.voxels)
        let sliceBufferLength = slicePixelCount * MemoryLayout<Float>.size

        guard let outBuffer = device.makeBuffer(length: sliceBufferLength,
                                                options: .storageModeShared) else {
            fatalError("❌ Failed to create output buffer for axial slice.")
        }

        var widthVar = UInt32(width)
        var heightVar = UInt32(height)
        var depthVar = UInt32(depth)
        var sliceIndexVar = UInt32(z)

        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            fatalError("❌ Failed to create compute encoder for axialSlice.")
        }

        encoder.setComputePipelineState(axialPipeline)
        encoder.setBuffer(volumeBuffer, offset: 0, index: 0)
        encoder.setBuffer(outBuffer, offset: 0, index: 1)
        encoder.setBytes(&widthVar, length: MemoryLayout<UInt32>.size, index: 2)
        encoder.setBytes(&heightVar, length: MemoryLayout<UInt32>.size, index: 3)
        encoder.setBytes(&depthVar, length: MemoryLayout<UInt32>.size, index: 4)
        encoder.setBytes(&sliceIndexVar, length: MemoryLayout<UInt32>.size, index: 5)

        let threadsPerThreadgroup = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroups = MTLSize(
            width: (width + threadsPerThreadgroup.width - 1) / threadsPerThreadgroup.width,
            height: (height + threadsPerThreadgroup.height - 1) / threadsPerThreadgroup.height,
            depth: 1
        )

        encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        let outPointer = outBuffer.contents().bindMemory(to: Float.self, capacity: slicePixelCount)
        let slicePixels = Array(UnsafeBufferPointer(start: outPointer, count: slicePixelCount))

        return CIImage2D(
            width: width,
            height: height,
            pixels: slicePixels,
            orientation: .axial
        )
    }

    /// Coronal slice: y-plane, size = width x depth (x, z)
    public static func coronalSlice(from volume: CIImageVolume, y: Int) throws -> CIImage2D {
        guard y >= 0 && y < volume.height else {
            throw SliceExtractError.invalidIndex
        }
        let context = ChromaContext.shared
        let device = context.device
        let commandBuffer = context.makeCommandBuffer()

        let width = volume.width
        let height = volume.height
        let depth = volume.depth
        let slicePixelCount = width * depth

        let volumeBuffer = context.makeBuffer(from: volume.voxels)
        let sliceBufferLength = slicePixelCount * MemoryLayout<Float>.size

        guard let outBuffer = device.makeBuffer(length: sliceBufferLength,
                                                options: .storageModeShared) else {
            fatalError("❌ Failed to create output buffer for coronal slice.")
        }

        var widthVar = UInt32(width)
        var heightVar = UInt32(height)
        var depthVar = UInt32(depth)
        var sliceIndexVar = UInt32(y)

        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            fatalError("❌ Failed to create compute encoder for coronalSlice.")
        }

        encoder.setComputePipelineState(coronalPipeline)
        encoder.setBuffer(volumeBuffer, offset: 0, index: 0)
        encoder.setBuffer(outBuffer, offset: 0, index: 1)
        encoder.setBytes(&widthVar, length: MemoryLayout<UInt32>.size, index: 2)
        encoder.setBytes(&heightVar, length: MemoryLayout<UInt32>.size, index: 3)
        encoder.setBytes(&depthVar, length: MemoryLayout<UInt32>.size, index: 4)
        encoder.setBytes(&sliceIndexVar, length: MemoryLayout<UInt32>.size, index: 5)

        let threadsPerThreadgroup = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroups = MTLSize(
            width: (width + threadsPerThreadgroup.width - 1) / threadsPerThreadgroup.width,
            height: (depth + threadsPerThreadgroup.height - 1) / threadsPerThreadgroup.height,
            depth: 1
        )

        encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        let outPointer = outBuffer.contents().bindMemory(to: Float.self, capacity: slicePixelCount)
        let slicePixels = Array(UnsafeBufferPointer(start: outPointer, count: slicePixelCount))

        // Note: width x depth
        return CIImage2D(
            width: width,
            height: depth,
            pixels: slicePixels,
            orientation: .coronal
        )
    }

    /// Sagittal slice: x-plane, size = height x depth (y, z)
    public static func sagittalSlice(from volume: CIImageVolume, x: Int) throws -> CIImage2D {
        guard x >= 0 && x < volume.width else {
            throw SliceExtractError.invalidIndex
        }
        let context = ChromaContext.shared
        let device = context.device
        let commandBuffer = context.makeCommandBuffer()

        let width = volume.width
        let height = volume.height
        let depth = volume.depth
        let slicePixelCount = height * depth

        let volumeBuffer = context.makeBuffer(from: volume.voxels)
        let sliceBufferLength = slicePixelCount * MemoryLayout<Float>.size

        guard let outBuffer = device.makeBuffer(length: sliceBufferLength,
                                                options: .storageModeShared) else {
            fatalError("❌ Failed to create output buffer for sagittal slice.")
        }

        var widthVar = UInt32(width)
        var heightVar = UInt32(height)
        var depthVar = UInt32(depth)
        var sliceIndexVar = UInt32(x)

        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            fatalError("❌ Failed to create compute encoder for sagittalSlice.")
        }

        encoder.setComputePipelineState(sagittalPipeline)
        encoder.setBuffer(volumeBuffer, offset: 0, index: 0)
        encoder.setBuffer(outBuffer, offset: 0, index: 1)
        encoder.setBytes(&widthVar, length: MemoryLayout<UInt32>.size, index: 2)
        encoder.setBytes(&heightVar, length: MemoryLayout<UInt32>.size, index: 3)
        encoder.setBytes(&depthVar, length: MemoryLayout<UInt32>.size, index: 4)
        encoder.setBytes(&sliceIndexVar, length: MemoryLayout<UInt32>.size, index: 5)

        let threadsPerThreadgroup = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroups = MTLSize(
            width: (height + threadsPerThreadgroup.width - 1) / threadsPerThreadgroup.width,
            height: (depth + threadsPerThreadgroup.height - 1) / threadsPerThreadgroup.height,
            depth: 1
        )

        encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        let outPointer = outBuffer.contents().bindMemory(to: Float.self, capacity: slicePixelCount)
        let slicePixels = Array(UnsafeBufferPointer(start: outPointer, count: slicePixelCount))

        // Note: height x depth
        return CIImage2D(
            width: height,
            height: depth,
            pixels: slicePixels,
            orientation: .sagittal
        )
    }
}

enum SliceExtractError: Error {
    case invalidIndex
}

extension SliceExtractGPU {
    static func extractSlice(
        from volume: CIImageVolume,
        orientation: SliceOrientation,
        index: Int,
        backend: ChromaProcessingBackend
    ) throws -> CIImage2D {
        switch backend {
        case .gpu:
            return try extractGPU(
                from: volume,
                orientation: orientation,
                index: index
            )
        case .cpu:
            return try extractCPU(
                from: volume,
                orientation: orientation,
                index: index
            )
        }
    }

    private static func extractGPU(
        from volume: CIImageVolume,
        orientation: SliceOrientation,
        index: Int
    ) throws -> CIImage2D {
        switch orientation {
        case .axial:
            return try axialSlice(from: volume, z: index)
        case .coronal:
            return try coronalSlice(from: volume, y: index)
        case .sagittal:
            return try sagittalSlice(from: volume, x: index)
        }
    }

    private static func extractCPU(
        from volume: CIImageVolume,
        orientation: SliceOrientation,
        index: Int
    ) throws -> CIImage2D {
        switch orientation {
        case .axial:
            guard index >= 0 && index < volume.depth else { throw SliceExtractError.invalidIndex }
            let start = index * volume.width * volume.height
            let end = start + (volume.width * volume.height)
            let slicePixels = Array(volume.voxels[start..<end])
            return CIImage2D(
                width: volume.width,
                height: volume.height,
                pixels: slicePixels,
                orientation: .axial
            )
        case .coronal:
            guard index >= 0 && index < volume.height else { throw SliceExtractError.invalidIndex }
            var pixels: [Float] = .init(repeating: 0, count: volume.width * volume.depth)
            var cursor = 0
            for z in 0..<volume.depth {
                let base = z * volume.height * volume.width + index * volume.width
                let rowRange = base..<(base + volume.width)
                pixels.replaceSubrange(cursor..<(cursor + volume.width), with: volume.voxels[rowRange])
                cursor += volume.width
            }
            return CIImage2D(
                width: volume.width,
                height: volume.depth,
                pixels: pixels,
                orientation: .coronal
            )
        case .sagittal:
            guard index >= 0 && index < volume.width else { throw SliceExtractError.invalidIndex }
            var pixels: [Float] = .init(repeating: 0, count: volume.height * volume.depth)
            var cursor = 0
            for z in 0..<volume.depth {
                for y in 0..<volume.height {
                    let flatIndex = z * volume.height * volume.width + y * volume.width + index
                    pixels[cursor] = volume.voxels[flatIndex]
                    cursor += 1
                }
            }
            return CIImage2D(
                width: volume.height,
                height: volume.depth,
                pixels: pixels,
                orientation: .sagittal
            )
        }
    }
}
