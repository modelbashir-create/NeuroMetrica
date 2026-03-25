import Foundation
import simd
#if canImport(Metal)
import Metal
#endif

public enum MetalSliceRendererError: Error {
    case metalUnavailable
    case pipelineUnavailable(String)
    case libraryUnavailable
    case functionUnavailable
    case pipelineStateCreationFailed
    case outputBufferUnavailable
    case commandBufferFailed(String)
    case unsupportedOrientation
    case unsupportedComponentType
    case unsupportedComponentsPerPixel
    case notImplemented
}

private enum MetalScalarType: UInt32 {
    case uint16 = 0
    case int16 = 1
    case float32 = 2
    case uint8 = 3
}

private struct SliceRenderParams {
    var sizeX: UInt32
    var sizeY: UInt32
    var sizeZ: UInt32
    var outputWidth: UInt32
    var outputHeight: UInt32
    var sliceIndex: UInt32
    var bytesPerVoxel: UInt32
    var scalarType: UInt32
    var window: Float
    var level: Float
    var origin: SIMD4<Float>
    var spacing: SIMD4<Float>
    var axisX: SIMD4<Float>
    var axisY: SIMD4<Float>
    var axisZ: SIMD4<Float>
    var invRow0: SIMD4<Float>
    var invRow1: SIMD4<Float>
    var invRow2: SIMD4<Float>
    var rescaleSlope: Float
    var rescaleIntercept: Float
    var interpolationMode: UInt32
    var validDirection: UInt32
}

private struct VolumeRenderParams {
    var sizeX: UInt32
    var sizeY: UInt32
    var sizeZ: UInt32
    var outputWidth: UInt32
    var outputHeight: UInt32
    var bytesPerVoxel: UInt32
    var scalarType: UInt32
    var window: Float
    var level: Float
    var step: Float
}

public struct MetalPreparedVolume: @unchecked Sendable {
    public let buffer: Any
    public let byteCount: Int
    public let sizeX: Int
    public let sizeY: Int
    public let sizeZ: Int
    public let sizeT: Int
    public let spacing: SIMD3<Double>
    public let origin: SIMD3<Double>
    public let direction: [Double]
    public let rescaleSlope: Double
    public let rescaleIntercept: Double
    public let componentType: CIPixelComponentType
    public let componentsPerPixel: Int
    public let bytesPerComponent: Int
}

public struct MetalSliceRenderRequest: Sendable {
    public let volume: CImageVolume
    public let orientation: SliceOrientation
    public let index: Int
    public let window: Float
    public let level: Float
    public let rescaleSlope: Float
    public let rescaleIntercept: Float
    public let interpolation: MPRInterpolation

    public init(
        volume: CImageVolume,
        orientation: SliceOrientation,
        index: Int,
        window: Float,
        level: Float,
        rescaleSlope: Float = 1.0,
        rescaleIntercept: Float = 0.0,
        interpolation: MPRInterpolation = .linear
    ) {
        self.volume = volume
        self.orientation = orientation
        self.index = index
        self.window = window
        self.level = level
        self.rescaleSlope = rescaleSlope
        self.rescaleIntercept = rescaleIntercept
        self.interpolation = interpolation
    }
}

public struct MetalVolumeRenderRequest: Sendable {
    public let volume: CImageVolume
    public let orientation: SliceOrientation
    public let window: Float
    public let level: Float
    public let step: Float

    public init(
        volume: CImageVolume,
        orientation: SliceOrientation,
        window: Float,
        level: Float,
        step: Float
    ) {
        self.volume = volume
        self.orientation = orientation
        self.window = window
        self.level = level
        self.step = step
    }
}

public final class MetalSliceRenderer: @unchecked Sendable {
#if canImport(Metal)
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineStates: [SliceOrientation: MTLComputePipelineState] = [:]
    private var volumePipelineStates: [SliceOrientation: MTLComputePipelineState] = [:]

    public init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            return nil
        }
        self.device = device
        self.commandQueue = commandQueue
    }

    public func prepare(volume: CImageVolume) throws -> MetalPreparedVolume {
        guard volume.valueCount > 0 else {
            throw MetalSliceRendererError.notImplemented
        }

        let bufferLength = volume.voxelData.count
        let voxelBuffer = volume.voxelData.withUnsafeBytes { bytes -> MTLBuffer? in
            guard let baseAddress = bytes.baseAddress else {
                return nil
            }
            return device.makeBuffer(bytes: baseAddress,
                                     length: bufferLength,
                                     options: .storageModeShared)
        }
        guard let buffer = voxelBuffer else {
            throw MetalSliceRendererError.pipelineUnavailable("Failed to allocate voxel buffer")
        }

        return MetalPreparedVolume(
            buffer: buffer,
            byteCount: bufferLength,
            sizeX: volume.sizeX,
            sizeY: volume.sizeY,
            sizeZ: volume.sizeZ,
            sizeT: volume.sizeT,
            spacing: SIMD3<Double>(volume.spacingX, volume.spacingY, volume.spacingZ),
            origin: SIMD3<Double>(volume.originX, volume.originY, volume.originZ),
            direction: volume.direction,
            rescaleSlope: volume.rescaleSlope,
            rescaleIntercept: volume.rescaleIntercept,
            componentType: volume.componentType,
            componentsPerPixel: volume.componentsPerPixel,
            bytesPerComponent: volume.bytesPerComponent
        )
    }

    public func renderSlice(
        preparedVolume: MetalPreparedVolume,
        request: MetalSliceRenderRequest
    ) throws -> CIImage2D {
        guard preparedVolume.componentsPerPixel == 1 else {
            throw MetalSliceRendererError.unsupportedComponentsPerPixel
        }

        let scalarType = try mapScalarType(preparedVolume.componentType)
        let pipeline = try makePipeline(for: request.orientation)
        guard let volumeBuffer = preparedVolume.buffer as? MTLBuffer else {
            throw MetalSliceRendererError.pipelineUnavailable("Prepared volume buffer missing")
        }

        let sizeX = preparedVolume.sizeX
        let sizeY = preparedVolume.sizeY
        let sizeZ = preparedVolume.sizeZ
        guard sizeZ > 0 else {
            throw MetalSliceRendererError.pipelineUnavailable("Invalid volume depth")
        }
        let outputDims = outputDimensions(for: request.orientation, sizeX: sizeX, sizeY: sizeY, sizeZ: sizeZ)
        let outputWidth = outputDims.width
        let outputHeight = outputDims.height
        let clampedIndex = clampIndex(request.index, orientation: request.orientation, sizeX: sizeX, sizeY: sizeY, sizeZ: sizeZ)
        let outputCount = outputWidth * outputHeight
        guard let outputBuffer = device.makeBuffer(length: outputCount, options: .storageModeShared) else {
            throw MetalSliceRendererError.outputBufferUnavailable
        }

        let bytesPerVoxel = preparedVolume.componentsPerPixel * preparedVolume.bytesPerComponent
        // CPU parity (applyWindowLevelInternal):
        // lower = level - window/2, upper = level + window/2, range = max(upper-lower, 1).
        let direction = preparedVolume.direction
        let dirRows = makeDirectionRows(direction)
        let axisX = SIMD3<Double>(dirRows.row0.x, dirRows.row1.x, dirRows.row2.x)
        let axisY = SIMD3<Double>(dirRows.row0.y, dirRows.row1.y, dirRows.row2.y)
        let axisZ = SIMD3<Double>(dirRows.row0.z, dirRows.row1.z, dirRows.row2.z)
        let inverse = invertDirection(dirRows)

        var params = SliceRenderParams(
            sizeX: UInt32(sizeX),
            sizeY: UInt32(sizeY),
            sizeZ: UInt32(sizeZ),
            outputWidth: UInt32(outputWidth),
            outputHeight: UInt32(outputHeight),
            sliceIndex: UInt32(clampedIndex),
            bytesPerVoxel: UInt32(bytesPerVoxel),
            scalarType: scalarType.rawValue,
            window: request.window,
            level: request.level,
            origin: SIMD4<Float>(Float(preparedVolume.origin.x), Float(preparedVolume.origin.y), Float(preparedVolume.origin.z), 0.0),
            spacing: SIMD4<Float>(Float(preparedVolume.spacing.x), Float(preparedVolume.spacing.y), Float(preparedVolume.spacing.z), 0.0),
            axisX: SIMD4<Float>(Float(axisX.x), Float(axisX.y), Float(axisX.z), 0.0),
            axisY: SIMD4<Float>(Float(axisY.x), Float(axisY.y), Float(axisY.z), 0.0),
            axisZ: SIMD4<Float>(Float(axisZ.x), Float(axisZ.y), Float(axisZ.z), 0.0),
            invRow0: SIMD4<Float>(Float(inverse.row0.x), Float(inverse.row0.y), Float(inverse.row0.z), 0.0),
            invRow1: SIMD4<Float>(Float(inverse.row1.x), Float(inverse.row1.y), Float(inverse.row1.z), 0.0),
            invRow2: SIMD4<Float>(Float(inverse.row2.x), Float(inverse.row2.y), Float(inverse.row2.z), 0.0),
            rescaleSlope: request.rescaleSlope,
            rescaleIntercept: request.rescaleIntercept,
            interpolationMode: request.interpolation == .linear ? 0 : 1,
            validDirection: inverse.valid ? 1 : 0
        )

        guard let paramsBuffer = device.makeBuffer(bytes: &params,
                                                   length: MemoryLayout<SliceRenderParams>.stride,
                                                   options: .storageModeShared) else {
            throw MetalSliceRendererError.pipelineUnavailable("Failed to allocate params buffer")
        }

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw MetalSliceRendererError.commandBufferFailed("Unable to create command buffer")
        }

        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(volumeBuffer, offset: 0, index: 0)
        encoder.setBuffer(outputBuffer, offset: 0, index: 1)
        encoder.setBuffer(paramsBuffer, offset: 0, index: 2)

        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroupCount = MTLSize(
            width: (outputWidth + threadgroupSize.width - 1) / threadgroupSize.width,
            height: (outputHeight + threadgroupSize.height - 1) / threadgroupSize.height,
            depth: 1
        )

        encoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        if let error = commandBuffer.error {
            throw MetalSliceRendererError.commandBufferFailed(error.localizedDescription)
        }

        logRenderDiagnostics(
            orientation: request.orientation,
            sliceIndex: clampedIndex,
            width: outputWidth,
            height: outputHeight,
            componentType: preparedVolume.componentType,
            window: request.window,
            level: request.level
        )

        let outputData = Data(bytes: outputBuffer.contents(), count: outputCount)
        return CIImage2D(
            width: outputWidth,
            height: outputHeight,
            componentsPerPixel: 1,
            componentType: .uint8,
            bytesPerComponent: 1,
            bytesPerRow: outputWidth,
            orientation: request.orientation,
            sliceIndex: clampedIndex,
            data: outputData
        )
    }

    public func renderVolume(
        preparedVolume: MetalPreparedVolume,
        request: MetalVolumeRenderRequest
    ) throws -> CIImage2D {
        guard preparedVolume.componentsPerPixel == 1 else {
            throw MetalSliceRendererError.unsupportedComponentsPerPixel
        }

        let scalarType = try mapScalarType(preparedVolume.componentType)
        let pipeline = try makeVolumePipeline(for: request.orientation)
        guard let volumeBuffer = preparedVolume.buffer as? MTLBuffer else {
            throw MetalSliceRendererError.pipelineUnavailable("Prepared volume buffer missing")
        }

        let sizeX = preparedVolume.sizeX
        let sizeY = preparedVolume.sizeY
        let sizeZ = preparedVolume.sizeZ
        guard sizeZ > 0 else {
            throw MetalSliceRendererError.pipelineUnavailable("Invalid volume depth")
        }

        let outputDims = outputDimensions(for: request.orientation, sizeX: sizeX, sizeY: sizeY, sizeZ: sizeZ)
        let outputWidth = outputDims.width
        let outputHeight = outputDims.height
        let outputCount = outputWidth * outputHeight
        guard let outputBuffer = device.makeBuffer(length: outputCount, options: .storageModeShared) else {
            throw MetalSliceRendererError.outputBufferUnavailable
        }

        let bytesPerVoxel = preparedVolume.componentsPerPixel * preparedVolume.bytesPerComponent
        let step = max(request.step, 1.0)
        var params = VolumeRenderParams(
            sizeX: UInt32(sizeX),
            sizeY: UInt32(sizeY),
            sizeZ: UInt32(sizeZ),
            outputWidth: UInt32(outputWidth),
            outputHeight: UInt32(outputHeight),
            bytesPerVoxel: UInt32(bytesPerVoxel),
            scalarType: scalarType.rawValue,
            window: request.window,
            level: request.level,
            step: step
        )

        guard let paramsBuffer = device.makeBuffer(bytes: &params,
                                                   length: MemoryLayout<VolumeRenderParams>.stride,
                                                   options: .storageModeShared) else {
            throw MetalSliceRendererError.pipelineUnavailable("Failed to allocate params buffer")
        }

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw MetalSliceRendererError.commandBufferFailed("Unable to create command buffer")
        }

        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(volumeBuffer, offset: 0, index: 0)
        encoder.setBuffer(outputBuffer, offset: 0, index: 1)
        encoder.setBuffer(paramsBuffer, offset: 0, index: 2)

        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroupCount = MTLSize(
            width: (outputWidth + threadgroupSize.width - 1) / threadgroupSize.width,
            height: (outputHeight + threadgroupSize.height - 1) / threadgroupSize.height,
            depth: 1
        )

        encoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        if let error = commandBuffer.error {
            throw MetalSliceRendererError.commandBufferFailed(error.localizedDescription)
        }

        logVolumeRenderDiagnostics(
            orientation: request.orientation,
            width: outputWidth,
            height: outputHeight,
            componentType: preparedVolume.componentType,
            window: request.window,
            level: request.level,
            step: step
        )

        let outputData = Data(bytes: outputBuffer.contents(), count: outputCount)
        return CIImage2D(
            width: outputWidth,
            height: outputHeight,
            componentsPerPixel: 1,
            componentType: .uint8,
            bytesPerComponent: 1,
            bytesPerRow: outputWidth,
            orientation: request.orientation,
            sliceIndex: 0,
            data: outputData
        )
    }

    private func makePipeline(for orientation: SliceOrientation) throws -> MTLComputePipelineState {
        if let existing = pipelineStates[orientation] {
            return existing
        }

        let library: MTLLibrary
#if SWIFT_PACKAGE
        if let defaultLibrary = try? device.makeDefaultLibrary(bundle: .module) {
            library = defaultLibrary
        } else if let defaultLibrary = device.makeDefaultLibrary() {
            library = defaultLibrary
        } else {
            throw MetalSliceRendererError.libraryUnavailable
        }
#else
        guard let defaultLibrary = device.makeDefaultLibrary() else {
            throw MetalSliceRendererError.libraryUnavailable
        }
        library = defaultLibrary
#endif

        let functionName: String
        switch orientation {
        case .axial:
            functionName = "renderAxialSlice"
        case .coronal:
            functionName = "renderCoronalSlice"
        case .sagittal:
            functionName = "renderSagittalSlice"
        }
        guard let function = library.makeFunction(name: functionName) else {
            throw MetalSliceRendererError.functionUnavailable
        }
        do {
            let pipeline = try device.makeComputePipelineState(function: function)
            pipelineStates[orientation] = pipeline
            return pipeline
        } catch {
            throw MetalSliceRendererError.pipelineStateCreationFailed
        }
    }

    private func makeVolumePipeline(for orientation: SliceOrientation) throws -> MTLComputePipelineState {
        if let existing = volumePipelineStates[orientation] {
            return existing
        }

        let library: MTLLibrary
#if SWIFT_PACKAGE
        if let defaultLibrary = try? device.makeDefaultLibrary(bundle: .module) {
            library = defaultLibrary
        } else if let defaultLibrary = device.makeDefaultLibrary() {
            library = defaultLibrary
        } else {
            throw MetalSliceRendererError.libraryUnavailable
        }
#else
        guard let defaultLibrary = device.makeDefaultLibrary() else {
            throw MetalSliceRendererError.libraryUnavailable
        }
        library = defaultLibrary
#endif

        let functionName: String
        switch orientation {
        case .axial:
            functionName = "renderAxialVolume"
        case .coronal:
            functionName = "renderCoronalVolume"
        case .sagittal:
            functionName = "renderSagittalVolume"
        }
        guard let function = library.makeFunction(name: functionName) else {
            throw MetalSliceRendererError.functionUnavailable
        }
        do {
            let pipeline = try device.makeComputePipelineState(function: function)
            volumePipelineStates[orientation] = pipeline
            return pipeline
        } catch {
            throw MetalSliceRendererError.pipelineStateCreationFailed
        }
    }

    private func mapScalarType(_ type: CIPixelComponentType) throws -> MetalScalarType {
        switch type {
        case .uint16:
            return .uint16
        case .int16:
            return .int16
        case .float32:
            return .float32
        case .uint8:
            return .uint8
        }
    }

    private func outputDimensions(for orientation: SliceOrientation, sizeX: Int, sizeY: Int, sizeZ: Int) -> (width: Int, height: Int) {
        switch orientation {
        case .axial:
            return (width: sizeX, height: sizeY)
        case .coronal:
            return (width: sizeX, height: sizeZ)
        case .sagittal:
            return (width: sizeY, height: sizeZ)
        }
    }

    private struct DirectionRows {
        let row0: SIMD3<Double>
        let row1: SIMD3<Double>
        let row2: SIMD3<Double>
    }

    private struct InverseDirection {
        let row0: SIMD3<Double>
        let row1: SIMD3<Double>
        let row2: SIMD3<Double>
        let valid: Bool
    }

    private func makeDirectionRows(_ direction: [Double]) -> DirectionRows {
        let row0 = SIMD3<Double>(direction[0], direction[1], direction[2])
        let row1 = SIMD3<Double>(direction[4], direction[5], direction[6])
        let row2 = SIMD3<Double>(direction[8], direction[9], direction[10])
        return DirectionRows(row0: row0, row1: row1, row2: row2)
    }

    private func invertDirection(_ rows: DirectionRows) -> InverseDirection {
        let a = rows.row0.x, b = rows.row0.y, c = rows.row0.z
        let d = rows.row1.x, e = rows.row1.y, f = rows.row1.z
        let g = rows.row2.x, h = rows.row2.y, i = rows.row2.z

        let det = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g)
        if abs(det) < 1e-12 {
            return InverseDirection(
                row0: SIMD3<Double>(0, 0, 0),
                row1: SIMD3<Double>(0, 0, 0),
                row2: SIMD3<Double>(0, 0, 0),
                valid: false
            )
        }
        let invDet = 1.0 / det
        let row0 = SIMD3<Double>(
            (e * i - f * h) * invDet,
            (c * h - b * i) * invDet,
            (b * f - c * e) * invDet
        )
        let row1 = SIMD3<Double>(
            (f * g - d * i) * invDet,
            (a * i - c * g) * invDet,
            (c * d - a * f) * invDet
        )
        let row2 = SIMD3<Double>(
            (d * h - e * g) * invDet,
            (b * g - a * h) * invDet,
            (a * e - b * d) * invDet
        )

        return InverseDirection(row0: row0, row1: row1, row2: row2, valid: true)
    }

    private func clampIndex(_ index: Int, orientation: SliceOrientation, sizeX: Int, sizeY: Int, sizeZ: Int) -> Int {
        switch orientation {
        case .axial:
            return min(max(index, 0), max(sizeZ - 1, 0))
        case .coronal:
            return min(max(index, 0), max(sizeY - 1, 0))
        case .sagittal:
            return min(max(index, 0), max(sizeX - 1, 0))
        }
    }

    private func logRenderDiagnostics(
        orientation: SliceOrientation,
        sliceIndex: Int,
        width: Int,
        height: Int,
        componentType: CIPixelComponentType,
        window: Float,
        level: Float
    ) {
        NSLog("ChromaEngine GPU slice render: axis=%@ idx=%d dims=%dx%d type=%@ WW/WL=%.3f/%.3f",
              "\(orientation)", sliceIndex, width, height, componentTypeLabel(componentType), window, level)
    }

    private func logVolumeRenderDiagnostics(
        orientation: SliceOrientation,
        width: Int,
        height: Int,
        componentType: CIPixelComponentType,
        window: Float,
        level: Float,
        step: Float
    ) {
        NSLog("ChromaEngine GPU volume render: axis=%@ dims=%dx%d type=%@ WW/WL=%.3f/%.3f step=%.2f",
              "\(orientation)", width, height, componentTypeLabel(componentType), window, level, step)
    }

    private func componentTypeLabel(_ type: CIPixelComponentType) -> String {
        switch type {
        case .uint8:
            return "UInt8"
        case .uint16:
            return "UInt16"
        case .int16:
            return "Int16"
        case .float32:
            return "Float32"
        }
    }
#else
    public init?() {
        return nil
    }

    public func prepare(volume: CImageVolume) throws -> MetalPreparedVolume {
        _ = volume
        throw MetalSliceRendererError.metalUnavailable
    }

    public func renderSlice(
        preparedVolume: MetalPreparedVolume,
        request: MetalSliceRenderRequest
    ) throws -> CIImage2D {
        _ = preparedVolume
        _ = request
        throw MetalSliceRendererError.metalUnavailable
    }

    public func renderVolume(
        preparedVolume: MetalPreparedVolume,
        request: MetalVolumeRenderRequest
    ) throws -> CIImage2D {
        _ = preparedVolume
        _ = request
        throw MetalSliceRendererError.metalUnavailable
    }
#endif
}
