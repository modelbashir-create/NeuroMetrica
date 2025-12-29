//
//  ITKImageDescriptor.swift
//  ChromaImagingCore
//
//  Lightweight Swift representation of an ITK image/volume.
//  Returned by ITKImageIO and consumed by ChromaEngineKit.
//

import Foundation
import ITKBridge

/// Pixel type classification coming out of the ITK bridge.
///
/// This mirrors `ITKPixelTypeC` in `ITKBridge.h` and is intentionally
/// high-level: scalar vs RGB vs vector, etc. The *numeric* component
/// type (uint16, float32, …) is described separately by
/// `componentBytes` and `isSigned`.
public enum ITKPixelType: Int32 {
    case unknown = 0
    case scalar  = 1
    case rgb     = 2
    case rgba    = 3
    case vector  = 4
    case complex = 5

    public init(cPixelType: ITKPixelTypeC) {
        self = ITKPixelType(rawValue: cPixelType.rawValue) ?? .unknown
    }
}

/// Swift-side descriptor for an ITK-loaded image/volume.
///
/// This is the only type that crosses from the ITK bridge
/// (ChromaImagingCore) into the higher-level engine (ChromaEngineKit).
/// ChromaEngineKit will convert this into its canonical volume/metadata
/// types and **copy** the voxel buffer into its own storage.
///
/// Memory ownership:
/// - `bufferPointer` points into memory owned by the ITK bridge.
/// - The bridge allocates and ultimately frees that memory via
///   `ITKFreeImageDescriptor`.
/// - Callers must copy out the data they need *before* asking the
///   bridge to free the descriptor.
public struct ITKImageDescriptor {

    // MARK: Geometry

    /// Image dimension (typically 3 for volumetric medical images).
    public let dimension: Int

    /// Number of voxels along each axis (length == dimension).
    public let size: [Int]

    /// Physical spacing (in mm) along each axis (length == dimension).
    public let spacing: [Double]

    /// World-space origin (in mm) of index (0,0,0,…).
    public let origin: [Double]

    /// Flattened direction cosine matrix (row-major, dimension x dimension).
    public let direction: [Double]

    // MARK: Pixel description

    /// High-level pixel type (scalar, RGB, vector, etc.).
    public let pixelType: ITKPixelType

    /// Number of scalar components per pixel (1 for scalar, 3 for RGB, etc.).
    public let componentsPerPixel: Int

    /// Total number of scalar values in the buffer:
    ///   valueCount = product(size) * componentsPerPixel.
    public let valueCount: Int

    /// Size in bytes of a single scalar component
    /// (e.g. 2 for uint16, 4 for float32).
    public let componentBytes: Int

    /// Whether the scalar component type is signed (true) or unsigned (false).
    public let isSigned: Bool

    // MARK: Buffer

    /// Pointer to a contiguous voxel buffer owned by the ITK bridge.
    ///
    /// Layout is x-fastest, then y, then z, then component:
    ///   index = (((k * sizeY + j) * sizeX + i) * componentsPerPixel + c)
    ///
    /// Callers **must copy** this buffer into their own storage before
    /// the bridge frees it.
    public let bufferPointer: UnsafeRawPointer?

    /// Convenience: total byte size of the buffer.
    public var totalByteCount: Int {
        valueCount * componentBytes
    }

    // MARK: Debug

    /// Optional human-readable description for logging / debugging.
    public let debugDescription: String?

    /// Raw metadata JSON emitted by the bridge (string map).
    public let metadataJSON: String?

    /// Parsed metadata map (lossless numeric types preserved).
    public let metadata: [String: ITKMetadataValue]

    private let metadataPointer: UnsafePointer<CChar>?

    // MARK: Designated init

    public init(
        dimension: Int,
        size: [Int],
        spacing: [Double],
        origin: [Double],
        direction: [Double],
        pixelType: ITKPixelType,
        componentsPerPixel: Int,
        valueCount: Int,
        componentBytes: Int,
        isSigned: Bool,
        bufferPointer: UnsafeRawPointer?,
        debugDescription: String? = nil,
        metadataJSON: String? = nil,
        metadata: [String: ITKMetadataValue] = [:],
        metadataPointer: UnsafePointer<CChar>? = nil
    ) {
        self.dimension = dimension
        self.size = size
        self.spacing = spacing
        self.origin = origin
        self.direction = direction
        self.pixelType = pixelType
        self.componentsPerPixel = componentsPerPixel
        self.valueCount = valueCount
        self.componentBytes = componentBytes
        self.isSigned = isSigned
        self.bufferPointer = bufferPointer
        self.debugDescription = debugDescription
        self.metadataJSON = metadataJSON
        self.metadata = metadata
        self.metadataPointer = metadataPointer
    }
}

public enum ITKMetadataValue: Sendable, Equatable {
    case string(String)
    case number(Double)
    case array([Double])
    case boolean(Bool)
}

// MARK: - C bridge helpers

public extension ITKImageDescriptor {

    /// Convenience initializer from the C-side `ITKImageDescriptorC`
    /// defined in `ITKBridge.h`.
    init(cDescriptor: ITKImageDescriptorC) {
        // Make a mutable copy so we can take `inout` pointers to its tuples.
        var desc = cDescriptor

        let dim = Int(desc.dimension)
        // Clamp dimension into [1,4] defensive range.
        let clampedDim = max(1, min(dim, 4))

        // Helper: read an array of Int from a fixed-size tuple field.
        func intArray<T>(from tuple: inout T, maxCount: Int) -> [Int] {
            let totalBytes = MemoryLayout<T>.size
            let elementSize = MemoryLayout<Int>.size
            let capacity = totalBytes / elementSize
            let count = min(maxCount, capacity)

            return withUnsafePointer(to: &tuple) { tuplePtr in
                tuplePtr.withMemoryRebound(to: Int.self, capacity: capacity) { intPtr in
                    var result: [Int] = []
                    result.reserveCapacity(count)
                    for i in 0..<count {
                        result.append(intPtr[i])
                    }
                    return result
                }
            }
        }

        // Helper: read an array of Double from a fixed-size tuple field.
        func doubleArray<T>(from tuple: inout T, maxCount: Int) -> [Double] {
            let totalBytes = MemoryLayout<T>.size
            let elementSize = MemoryLayout<Double>.size
            let capacity = totalBytes / elementSize
            let count = min(maxCount, capacity)

            return withUnsafePointer(to: &tuple) { tuplePtr in
                tuplePtr.withMemoryRebound(to: Double.self, capacity: capacity) { doublePtr in
                    var result: [Double] = []
                    result.reserveCapacity(count)
                    for i in 0..<count {
                        result.append(doublePtr[i])
                    }
                    return result
                }
            }
        }

        // Geometry
        let sizeArray: [Int] = intArray(from: &desc.size, maxCount: clampedDim)
        let spacingArray: [Double] = doubleArray(from: &desc.spacing, maxCount: clampedDim)
        let originArray: [Double] = doubleArray(from: &desc.origin, maxCount: clampedDim)

        let directionCount = clampedDim * clampedDim
        let directionArray: [Double] = doubleArray(from: &desc.direction, maxCount: directionCount)

        // Pixel + buffer metadata
        let pixelType = ITKPixelType(cPixelType: desc.pixelType)
        let componentsPerPixel = Int(desc.componentsPerPixel)
        let valueCount = Int(desc.valueCount)
        let componentBytes = Int(desc.componentBytes)
        let isSigned = (desc.isSigned != 0)

        let ptr = UnsafeRawPointer(desc.bufferHandle)
        let metadataPointer = UnsafePointer<CChar>(desc.metadataJSON)
        let metadataJSON = metadataPointer != nil ? String(cString: metadataPointer!) : nil
        let metadata = parseMetadataJSON(metadataJSON)

        let debug = """
        dim=\(clampedDim), size=\(sizeArray), spacing=\(spacingArray), \
        origin=\(originArray), directionCount=\(directionArray.count), \
        pixelType=\(pixelType), components=\(componentsPerPixel), \
        valueCount=\(valueCount), componentBytes=\(componentBytes), \
        signed=\(isSigned)
        """

        self.init(
            dimension: clampedDim,
            size: sizeArray,
            spacing: spacingArray,
            origin: originArray,
            direction: directionArray,
            pixelType: pixelType,
            componentsPerPixel: componentsPerPixel,
            valueCount: valueCount,
            componentBytes: componentBytes,
            isSigned: isSigned,
            bufferPointer: ptr,
            debugDescription: debug,
            metadataJSON: metadataJSON,
            metadata: metadata,
            metadataPointer: metadataPointer
        )
    }

    /// Free the bridge-owned resources (voxel buffer + metadata string).
    func freeBridgeResources() {
        guard bufferPointer != nil || metadataPointer != nil else { return }

        var cDescriptor = ITKImageDescriptorC()
        cDescriptor.bufferHandle = bufferPointer
        cDescriptor.valueCount = UInt64(valueCount)
        cDescriptor.metadataJSON = metadataPointer
        cDescriptor.metadataJSONLength = Int32(metadataJSON?.utf8.count ?? 0)
        ITKFreeImageDescriptor(&cDescriptor)
    }

    /// Free the bridge-owned voxel buffer.
    ///
    /// Call this after copying `bufferPointer` into your own storage.
    func freeBridgeBuffer() {
        guard bufferPointer != nil else { return }

        var cDescriptor = ITKImageDescriptorC()
        cDescriptor.bufferHandle = bufferPointer
        cDescriptor.valueCount = UInt64(valueCount)
        ITKFreeImageDescriptor(&cDescriptor)
    }
}

private func parseMetadataJSON(_ metadataJSON: String?) -> [String: ITKMetadataValue] {
    guard let metadataJSON,
          let data = metadataJSON.data(using: .utf8) else {
        return [:]
    }

    guard let object = try? JSONSerialization.jsonObject(with: data, options: []),
          let dictionary = object as? [String: Any] else {
        return [:]
    }

    var result: [String: ITKMetadataValue] = [:]
    result.reserveCapacity(dictionary.count)

    for (key, value) in dictionary {
        if let stringValue = value as? String {
            result[key] = .string(stringValue)
            continue
        }
        if let numberValue = value as? NSNumber {
            result[key] = .number(numberValue.doubleValue)
            continue
        }
        if let boolValue = value as? Bool {
            result[key] = .boolean(boolValue)
            continue
        }
        if let arrayValue = value as? [NSNumber] {
            result[key] = .array(arrayValue.map { $0.doubleValue })
            continue
        }
        if let arrayValue = value as? [Double] {
            result[key] = .array(arrayValue)
            continue
        }
    }

    return result
}
