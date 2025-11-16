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
    public static func axialSlice(from volume: CIImageVolume, z: Int) -> CIImage2D {
        precondition(z >= 0 && z < volume.depth, "❌ Axial slice index out of range.")
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
    public static func coronalSlice(from volume: CIImageVolume, y: Int) -> CIImage2D {
        precondition(y >= 0 && y < volume.height, "❌ Coronal slice index out of range.")
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
    public static func sagittalSlice(from volume: CIImageVolume, x: Int) -> CIImage2D {
        precondition(x >= 0 && x < volume.width, "❌ Sagittal slice index out of range.")
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
