// WindowLevelGPU.swift
// ChromaImagingKit

import Foundation
import Metal

/// GPU-accelerated window/level using Metal.
/// Useful when you’re already on GPU or want to batch operations.
public struct WindowLevelGPU {

    // Lazily create the compute pipeline once.
    private static let pipelineState: MTLComputePipelineState = {
        let context = ChromaContext.shared
        guard let function = context.library.makeFunction(name: "windowLevelKernel") else {
            fatalError("❌ Failed to find Metal function 'windowLevelKernel' in default library.")
        }
        do {
            return try context.device.makeComputePipelineState(function: function)
        } catch {
            fatalError("❌ Failed to create compute pipeline state for windowLevelKernel: \(error)")
        }
    }()

    /// Applies window/level to a 2D float image on the GPU.
    /// - Parameters:
    ///   - image: CIImage2D input (Float32 pixels in [min..max] range).
    ///   - window: Window width (WW).
    ///   - level: Window center (WL).
    /// - Returns: New CIImage2D after WW/WL and clamped to [0, 1].
    public static func apply(
        to image: CIImage2D,
        window: Float,
        level: Float
    ) -> CIImage2D {
        let context = ChromaContext.shared
        let device = context.device
        let commandBuffer = context.makeCommandBuffer()

        // Flattened pixel buffer
        let count = image.count

        // Input buffer
        let inBuffer = context.makeBuffer(from: image.pixels)

        // Output buffer
        let outBufferLength = count * MemoryLayout<Float>.size
        guard let outBuffer = device.makeBuffer(length: outBufferLength,
                                                options: .storageModeShared) else {
            fatalError("❌ Failed to create output Metal buffer for WW/WL.")
        }

        // Compute slope and intercept (same as CPU version):
        // norm = (pixel - (level - window/2)) / window
        let slope: Float = 1.0 / window
        let intercept: Float = -((level - window / 2.0) * slope)
        var slopeVar = slope
        var interceptVar = intercept
        var countVar = UInt32(count)

        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            fatalError("❌ Failed to create compute command encoder.")
        }

        encoder.setComputePipelineState(pipelineState)
        encoder.setBuffer(inBuffer, offset: 0, index: 0)
        encoder.setBuffer(outBuffer, offset: 0, index: 1)
        encoder.setBytes(&slopeVar, length: MemoryLayout<Float>.size, index: 2)
        encoder.setBytes(&interceptVar, length: MemoryLayout<Float>.size, index: 3)
        encoder.setBytes(&countVar, length: MemoryLayout<UInt32>.size, index: 4)

        // 1D grid over all pixels
        let threadsPerThreadgroup = MTLSize(width: min(pipelineState.maxTotalThreadsPerThreadgroup, 256),
                                            height: 1,
                                            depth: 1)
        let threadgroups = MTLSize(
            width: (count + threadsPerThreadgroup.width - 1) / threadsPerThreadgroup.width,
            height: 1,
            depth: 1
        )

        encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
        encoder.endEncoding()

        // For now: wait synchronously. Later we can make this async/await.
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // Read back results into a Swift array
        let outPointer = outBuffer.contents().bindMemory(to: Float.self, capacity: count)
        let outPixels = Array(UnsafeBufferPointer(start: outPointer, count: count))

        return CIImage2D(width: image.width, height: image.height, pixels: outPixels)
    }
}
