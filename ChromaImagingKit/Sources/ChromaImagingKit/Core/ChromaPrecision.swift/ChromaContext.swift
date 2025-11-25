//
//  ChromaContext.swift
//  ChromaImagingKit
//
//  Created by Mohamed Elbashir on 11/13/25.
//
import Foundation
import Metal
import MetalPerformanceShaders

/// Global GPU/CPU processing context for the imaging engine.
/// Similar to ITK's global factory, but modern and Apple-native.
/// Handles:
/// - Metal device
/// - Command queue
/// - Default Metal library
/// - Shared MPS device
/// - Thread-safe access
public final class ChromaContext: @unchecked Sendable {

    /// Singleton instance (safe and common in GPU frameworks)
    public static let shared = ChromaContext()

    /// The Metal device used for all GPU compute.
    public let device: MTLDevice

    /// Command queue for submitting compute commands.
    public let commandQueue: MTLCommandQueue

    /// Default Metal library (for your .metal files)
    public let library: MTLLibrary

    private init() {
        // Prefer high-performance GPU (Apple Silicon/M-series)
        guard let dev = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device.")
        }

        self.device = dev

        guard let queue = dev.makeCommandQueue() else {
            fatalError("Unable to create Metal command queue.")
        }

        self.commandQueue = queue

        do {
            self.library = try dev.makeDefaultLibrary(bundle: .module)
        } catch {
            fatalError("Failed to load Metal library: \(error)")
        }
    }

    // MARK: - Helpers

    /// Creates a command buffer with error handling.
    public func makeCommandBuffer() -> MTLCommandBuffer {
        guard let cb = commandQueue.makeCommandBuffer() else {
            fatalError("Failed to create command buffer.")
        }
        return cb
    }

    /// Creates a Metal buffer from a Float array.
    public func makeBuffer(from array: [Float]) -> MTLBuffer {
        let length = array.count * MemoryLayout<Float>.size
        guard let buffer = device.makeBuffer(bytes: array,
                                             length: length,
                                             options: [.storageModeShared]) else {
            fatalError("Failed to create Metal buffer.")
        }
        return buffer
    }
}
