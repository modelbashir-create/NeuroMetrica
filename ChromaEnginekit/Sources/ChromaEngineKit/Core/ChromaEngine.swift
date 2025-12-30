//
//  ChromaEngine.swift
//  ChromaEngineKit
//
//  High-level façade over ChromaImagingCore + ITK-backed IO.
//
//  NeuroMetrica (and any other app) should depend only on this type
//  via `ChromaEngineBridge` instead of talking directly to ITK or
//  low-level GPU/CPU kernels.
//

import Foundation
import simd
import ChromaImagingCore   // ITKImageIO + ITKImageDescriptor

// MARK: - Error Type

public enum ChromaEngineError: Error, LocalizedError {
    case notImplemented(String)

    public var errorDescription: String? {
        switch self {
        case .notImplemented(let feature):
            return "\(feature) is not implemented yet in ChromaEngine."
        }
    }
}

// MARK: - Engine

/// High-level engine façade used by NeuroMetrica.
///
/// IO DESIGN (Architecture 2.0)
/// -----------------------------
/// - All real-world file/series reading (DICOM, NIfTI, NRRD, MHA, …)
///   is owned by ChromaImagingCore’s ITK bridge.
/// - ChromaEngine exposes format-specific async APIs that delegate to
///   that IO layer. For now the methods are stubs that clearly throw
///   `notImplemented` but the *signatures* are stable.
///
/// PROCESSING DESIGN
/// -----------------
/// - Slices and projections operate on the canonical volume model
///   (`CImageVolume`) and return `CIImage2D` for the UI layer.
/// - Later we can route slice + WW/WL through ITK vs Native backends
///   without changing this public surface.
public struct ChromaEngine: Sendable {

    // MARK: - Init

    /// Default configuration.
    ///
    /// In the future this could accept a `ChromaEngineConfig` with
    /// backend choices (ITK vs Native), verification mode, etc.
    public var config: ChromaEngineConfig

    public init(config: ChromaEngineConfig = .standard) {
        self.config = config
    }

    // MARK: - Volume Loading (ITK-backed IO)

    /// Load a NIfTI volume from disk.
    ///
    /// Long-term: delegate to ITKImageIO / ITK bridge in
    /// ChromaImagingCore.
    public func loadNiftiVolume(from url: URL) async throws -> EngineVolumeDescriptor {
        try loadSingleFileVolume(from: url, sourceFormat: .nifti)
    }

    /// Load an NRRD volume from disk.
    ///
    /// Long-term: delegate to ITKImageIO / ITK bridge in
    /// ChromaImagingCore.
    public func loadNRRDVolume(from url: URL) async throws -> EngineVolumeDescriptor {
        try loadSingleFileVolume(from: url, sourceFormat: .nrrd)
    }

    /// Load a DICOM series from a directory.
    ///
    /// Long-term: delegate to ITK DICOM series reader (GDCM/DCMTK)
    /// via the ITK bridge.
    public func loadDicomSeries(from directoryURL: URL) async throws -> EngineVolumeDescriptor {
        let descriptor = try ITKImageIO.loadVolume(
            at: directoryURL,
            formatHint: .dicomSeries,
            dicomBackend: mapDicomBackend(config.dicomBackend)
        )
        return convertDescriptorToVolume(descriptor, sourceFormat: .dicom, sourceDescription: directoryURL.path)
    }

    /// Load a single-file DICOM volume (e.g., Secondary Capture).
    public func loadDicomFile(from url: URL) async throws -> EngineVolumeDescriptor {
        try loadSingleFileVolume(from: url, sourceFormat: .dicom)
    }

    // MARK: - Slice Generation + Window/Level

    /// Extract a 2D slice from a volume and apply window/level.
    ///
    /// - Parameters:
    ///   - volume: Canonical engine volume.
    ///   - orientation: Axial / coronal / sagittal.
    ///   - index: Zero-based slice index for that orientation.
    ///   - window: Window width.
    ///   - level: Window level (center).
    ///
    /// - Returns: A `CIImage2D` ready for conversion to CGImage /
    ///            SwiftUI `Image` in the app layer.
    public func makeSlice(
        from volume: CImageVolume,
        orientation: SliceOrientation,
        index: Int,
        window: Float,
        level: Float
    ) async throws -> CIImage2D {
        try makeSliceCPU(
            from: volume,
            orientation: orientation,
            index: index,
            window: window,
            level: level
        )
    }

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
        try makeSliceFromPlane(
            volume: volume,
            plane: plane,
            window: window,
            level: level
        )
    }
}

// MARK: - Private helpers

private extension ChromaEngine {

    func loadSingleFileVolume(
        from url: URL,
        sourceFormat: CIMetadataSourceFormat
    ) throws -> EngineVolumeDescriptor {
        let descriptor = try ITKImageIO.loadVolume(
            at: url,
            formatHint: .singleFile,
            dicomBackend: mapDicomBackend(config.dicomBackend)
        )
        return convertDescriptorToVolume(descriptor, sourceFormat: sourceFormat, sourceDescription: url.path)
    }

    func mapDicomBackend(_ backend: DicomBackend) -> ITKDicomBackend {
        switch backend {
        case .dcmtkPreferred:
            return .dcmtk
        case .gdcm:
            return .gdcm
        }
    }

    func convertDescriptorToVolume(
        _ descriptor: ITKImageDescriptor,
        sourceFormat: CIMetadataSourceFormat,
        sourceDescription: String?
    ) -> EngineVolumeDescriptor {
        let sizeX = descriptor.size[safe: 0] ?? 1
        let sizeY = descriptor.size[safe: 1] ?? 1
        let sizeZ = descriptor.size[safe: 2] ?? 1
        let sizeT = descriptor.size.count > 3 ? (descriptor.size[safe: 3] ?? 1) : 1

        let spacingX = descriptor.spacing[safe: 0] ?? 1.0
        let spacingY = descriptor.spacing[safe: 1] ?? 1.0
        let spacingZ = descriptor.spacing[safe: 2] ?? 1.0
        let spacingT = descriptor.spacing.count > 3 ? (descriptor.spacing[safe: 3] ?? 1.0) : 1.0

        let originX = descriptor.origin[safe: 0] ?? 0.0
        let originY = descriptor.origin[safe: 1] ?? 0.0
        let originZ = descriptor.origin[safe: 2] ?? 0.0
        let originT = descriptor.origin.count > 3 ? (descriptor.origin[safe: 3] ?? 0.0) : 0.0

        let direction = normalizedDirection(from: descriptor.direction)

        let componentType = mapComponentType(bytes: descriptor.componentBytes, isSigned: descriptor.isSigned)

        let data = copyBuffer(descriptor)
        let metadata = buildMetadata(from: descriptor, sourceFormat: sourceFormat, sourceDescription: sourceDescription)
        descriptor.freeBridgeResources()

        let volume = CImageVolume(
            dimension: descriptor.dimension,
            sizeX: sizeX,
            sizeY: sizeY,
            sizeZ: sizeZ,
            sizeT: sizeT,
            spacingX: spacingX,
            spacingY: spacingY,
            spacingZ: spacingZ,
            spacingT: spacingT,
            originX: originX,
            originY: originY,
            originZ: originZ,
            originT: originT,
            direction: direction,
            componentType: componentType,
            componentsPerPixel: descriptor.componentsPerPixel,
            bytesPerComponent: descriptor.componentBytes,
            isSigned: descriptor.isSigned,
            voxelData: data
        )

        return EngineVolumeDescriptor(volume: volume, metadata: metadata)
    }

    func copyBuffer(_ descriptor: ITKImageDescriptor) -> Data {
        guard let bufferPointer = descriptor.bufferPointer else {
            return Data()
        }

        return Data(bytes: bufferPointer, count: descriptor.totalByteCount)
    }

    func normalizedDirection(from direction: [Double]) -> [Double] {
        var matrix = Array(repeating: 0.0, count: 16)
        let dim = min(4, max(1, Int(sqrt(Double(direction.count)))))

        for row in 0..<dim {
            for col in 0..<dim {
                let srcIndex = row * dim + col
                let dstIndex = row * 4 + col
                if srcIndex < direction.count && dstIndex < matrix.count {
                    matrix[dstIndex] = direction[srcIndex]
                }
            }
        }

        // Fill remaining diagonal with 1.0 for 4x4 identity extension.
        for i in dim..<4 {
            matrix[i * 4 + i] = 1.0
        }

        return matrix
    }

    func mapComponentType(bytes: Int, isSigned: Bool) -> CIPixelComponentType {
        switch (bytes, isSigned) {
        case (1, _):
            return .uint8
        case (2, true):
            return .int16
        case (2, false):
            return .uint16
        case (4, _):
            return .float32
        default:
            return .float32
        }
    }

    func makeSliceCPU(
        from volume: CImageVolume,
        orientation: SliceOrientation,
        index: Int,
        window: Float,
        level: Float
    ) throws -> CIImage2D {
        let sizeX = volume.sizeX
        let sizeY = volume.sizeY
        let sizeZ = volume.sizeZ

        let width: Int
        let height: Int

        switch orientation {
        case .axial:
            width = sizeX
            height = sizeY
        case .coronal:
            width = sizeX
            height = sizeZ
        case .sagittal:
            width = sizeY
            height = sizeZ
        }

        let clampedIndex: Int
        switch orientation {
        case .axial:
            clampedIndex = min(max(index, 0), max(sizeZ - 1, 0))
        case .coronal:
            clampedIndex = min(max(index, 0), max(sizeY - 1, 0))
        case .sagittal:
            clampedIndex = min(max(index, 0), max(sizeX - 1, 0))
        }

        let plane = planeForOrientation(
            volume: volume,
            orientation: orientation,
            sliceIndex: clampedIndex,
            width: width,
            height: height
        )

        return try makeSliceFromPlane(
            volume: volume,
            plane: plane,
            window: window,
            level: level
        )
    }

    func makeSliceFromPlane(
        volume: CImageVolume,
        plane: PatientPlane,
        window: Float,
        level: Float
    ) throws -> CIImage2D {
        validateDirectionMatrix(volume: volume)

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

    func directionColumns(volume: CImageVolume) -> (x: SIMD3<Double>, y: SIMD3<Double>, z: SIMD3<Double>) {
        let dir = directionMatrix(volume: volume)
        let x = SIMD3<Double>(dir[0][0], dir[1][0], dir[2][0])
        let y = SIMD3<Double>(dir[0][1], dir[1][1], dir[2][1])
        let z = SIMD3<Double>(dir[0][2], dir[1][2], dir[2][2])
        return (x: x, y: y, z: z)
    }

    func directionMatrix(volume: CImageVolume) -> [[Double]] {
        let d = volume.direction
        return [
            [d[0], d[1], d[2]],
            [d[4], d[5], d[6]],
            [d[8], d[9], d[10]]
        ]
    }

    func multiply(_ matrix: [[Double]], _ vector: SIMD3<Double>) -> SIMD3<Double> {
        let x = matrix[0][0] * vector.x + matrix[0][1] * vector.y + matrix[0][2] * vector.z
        let y = matrix[1][0] * vector.x + matrix[1][1] * vector.y + matrix[1][2] * vector.z
        let z = matrix[2][0] * vector.x + matrix[2][1] * vector.y + matrix[2][2] * vector.z
        return SIMD3<Double>(x, y, z)
    }

    func invert3x3(_ matrix: [[Double]]) -> [[Double]]? {
        let a = matrix[0][0], b = matrix[0][1], c = matrix[0][2]
        let d = matrix[1][0], e = matrix[1][1], f = matrix[1][2]
        let g = matrix[2][0], h = matrix[2][1], i = matrix[2][2]

        let det = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g)
        if abs(det) < 1e-12 {
            return nil
        }
        let invDet = 1.0 / det
        return [
            [(e * i - f * h) * invDet, (c * h - b * i) * invDet, (b * f - c * e) * invDet],
            [(f * g - d * i) * invDet, (a * i - c * g) * invDet, (c * d - a * f) * invDet],
            [(d * h - e * g) * invDet, (b * g - a * h) * invDet, (a * e - b * d) * invDet]
        ]
    }

    func validateDirectionMatrix(volume: CImageVolume) {
        let dir = directionMatrix(volume: volume)
        let x = SIMD3<Double>(dir[0][0], dir[1][0], dir[2][0])
        let y = SIMD3<Double>(dir[0][1], dir[1][1], dir[2][1])
        let z = SIMD3<Double>(dir[0][2], dir[1][2], dir[2][2])

        let epsilon = 1e-4
        let xNorm = simd_length(x)
        let yNorm = simd_length(y)
        let zNorm = simd_length(z)
        let xy = abs(simd_dot(x, y))
        let xz = abs(simd_dot(x, z))
        let yz = abs(simd_dot(y, z))

        if abs(xNorm - 1.0) > epsilon || abs(yNorm - 1.0) > epsilon || abs(zNorm - 1.0) > epsilon ||
            xy > epsilon || xz > epsilon || yz > epsilon {
            NSLog("ChromaEngine: non-orthonormal direction matrix detected (norms: %.6f/%.6f/%.6f, dots: %.6f/%.6f/%.6f)",
                  xNorm, yNorm, zNorm, xy, xz, yz)
            assertionFailure("Non-orthonormal direction matrix detected; MPR may be inaccurate.")
        }

        let det = dir[0][0] * (dir[1][1] * dir[2][2] - dir[1][2] * dir[2][1])
            - dir[0][1] * (dir[1][0] * dir[2][2] - dir[1][2] * dir[2][0])
            + dir[0][2] * (dir[1][0] * dir[2][1] - dir[1][1] * dir[2][0])

        if det < 0 {
            NSLog("ChromaEngine: left-handed direction matrix detected (det=%.6f)", det)
            assertionFailure("Left-handed direction matrix detected; reslicing may be mirrored.")
        }
    }

    func buildMetadata(
        from descriptor: ITKImageDescriptor,
        sourceFormat: CIMetadataSourceFormat,
        sourceDescription: String?
    ) -> CIMetadata {
        let parsed = parseMetadataMap(descriptor.metadata)
        let metadata = CIMetadata(
            sourceFormat: sourceFormat,
            sourceDescription: sourceDescription,
            patientID: parsed.tags["0010,0020"],
            patientName: parsed.tags["0010,0010"],
            patientSex: parsed.tags["0010,0040"],
            patientBirthDate: parsed.tags["0010,0030"],
            patientAge: parsed.tags["0010,1010"],
            studyInstanceUID: parsed.tags["0020,000D"],
            seriesInstanceUID: parsed.tags["0020,000E"],
            frameOfReferenceUID: parsed.tags["0020,0052"],
            studyID: parsed.tags["0020,0010"],
            accessionNumber: parsed.tags["0008,0050"],
            studyDescription: parsed.tags["0008,1030"],
            seriesDescription: parsed.tags["0008,103E"],
            modality: parsed.tags["0008,0060"],
            bodyPartExamined: parsed.tags["0018,0015"],
            studyDate: parsed.tags["0008,0020"],
            studyTime: parsed.tags["0008,0030"],
            seriesNumber: parsed.seriesNumber,
            instanceNumber: parsed.instanceNumber,
            institutionName: parsed.tags["0008,0080"],
            manufacturer: parsed.tags["0008,0070"],
            manufacturerModelName: parsed.tags["0008,1090"],
            acquisitionDate: parsed.tags["0008,0022"] ?? parsed.tags["0008,0021"] ?? parsed.tags["0008,0020"],
            acquisitionTime: parsed.tags["0008,0032"] ?? parsed.tags["0008,0031"] ?? parsed.tags["0008,0030"],
            rows: parsed.rows ?? parseInt(parsed.tags["0028,0010"]),
            columns: parsed.columns ?? parseInt(parsed.tags["0028,0011"]),
            sliceThickness: parsed.sliceThickness ?? parseDouble(parsed.tags["0018,0050"]),
            spacingBetweenSlices: parsed.spacingBetweenSlices ?? parseDouble(parsed.tags["0018,0088"]),
            pixelSpacing: parsed.pixelSpacing ?? parsePixelSpacing(parsed.tags["0028,0030"]),
            bitsAllocated: parsed.bitsAllocated,
            bitsStored: parsed.bitsStored,
            pixelRepresentation: parsed.pixelRepresentation,
            highBit: parsed.highBit,
            rescaleIntercept: parsed.rescaleIntercept ?? parseDouble(parsed.tags["0028,1052"]),
            rescaleSlope: parsed.rescaleSlope ?? parseDouble(parsed.tags["0028,1053"]),
            windowCenter: parsed.windowCenter,
            windowWidth: parsed.windowWidth,
            transferSyntaxUID: parsed.transferSyntaxUID ?? parsed.tags["0002,0010"],
            pixelDataConsistentAcrossSlices: parsed.pixelDataConsistentAcrossSlices,
            geometryConsistentAcrossSlices: parsed.geometryConsistentAcrossSlices,
            numberOfFrames: parsed.numberOfFrames ?? parseInt(parsed.tags["0028,0008"]),
            numberOfInstances: parsed.numberOfInstances ?? parseInt(parsed.tags["0020,1209"]),
            imageOrientationPatientRow: parsed.imageOrientationPatientRow,
            imageOrientationPatientColumn: parsed.imageOrientationPatientColumn,
            imagePositionPatient: parsed.imagePositionPatient,
            imageOrientationConsistentAcrossSlices: parsed.imageOrientationConsistentAcrossSlices,
            additionalTags: parsed.tags
        )

        return metadata
    }

    struct ParsedMetadata {
        var tags: [String: String]
        var imageOrientationPatientRow: [Double]?
        var imageOrientationPatientColumn: [Double]?
        var imagePositionPatient: [Double]?
        var imageOrientationConsistentAcrossSlices: Bool?
        var pixelDataConsistentAcrossSlices: Bool?
        var geometryConsistentAcrossSlices: Bool?
        var seriesNumber: Int?
        var instanceNumber: Int?
        var bitsAllocated: Int?
        var bitsStored: Int?
        var highBit: Int?
        var pixelRepresentation: Int?
        var rescaleIntercept: Double?
        var rescaleSlope: Double?
        var windowCenter: [Double]?
        var windowWidth: [Double]?
        var rows: Int?
        var columns: Int?
        var sliceThickness: Double?
        var spacingBetweenSlices: Double?
        var pixelSpacing: CIPixelSpacing?
        var transferSyntaxUID: String?
        var numberOfFrames: Int?
        var numberOfInstances: Int?
    }

    func parseMetadataMap(_ metadata: [String: ITKMetadataValue]) -> ParsedMetadata {
        var tags: [String: String] = [:]
        var row: [Double]?
        var column: [Double]?
        var position: [Double]?
        var consistent: Bool?
        var seriesNumber: Int?
        var instanceNumber: Int?
        var bitsAllocated: Int?
        var bitsStored: Int?
        var highBit: Int?
        var pixelRepresentation: Int?
        var rescaleIntercept: Double?
        var rescaleSlope: Double?
        var windowCenter: [Double]?
        var windowWidth: [Double]?
        var rows: Int?
        var columns: Int?
        var sliceThickness: Double?
        var spacingBetweenSlices: Double?
        var pixelSpacing: CIPixelSpacing?
        var transferSyntaxUID: String?
        var numberOfFrames: Int?
        var numberOfInstances: Int?
        var pixelDataConsistentAcrossSlices: Bool?
        var geometryConsistentAcrossSlices: Bool?

        for (key, value) in metadata {
            switch value {
            case .string(let stringValue):
                tags[key] = stringValue
                switch key {
                case "0002,0010":
                    transferSyntaxUID = stringValue
                default:
                    break
                }
            case .number(let numberValue):
                tags[key] = formatNumber(numberValue)
                switch key {
                case "0020,0011": seriesNumber = Int(numberValue.rounded())
                case "0020,0013": instanceNumber = Int(numberValue.rounded())
                case "0028,0100": bitsAllocated = Int(numberValue.rounded())
                case "0028,0101": bitsStored = Int(numberValue.rounded())
                case "0028,0102": highBit = Int(numberValue.rounded())
                case "0028,0103": pixelRepresentation = Int(numberValue.rounded())
                case "0028,1052": rescaleIntercept = numberValue
                case "0028,1053": rescaleSlope = numberValue
                case "0028,0010": rows = Int(numberValue.rounded())
                case "0028,0011": columns = Int(numberValue.rounded())
                case "0018,0050": sliceThickness = numberValue
                case "0018,0088": spacingBetweenSlices = numberValue
                case "0028,0008": numberOfFrames = Int(numberValue.rounded())
                case "0020,1209": numberOfInstances = Int(numberValue.rounded())
                default: break
                }
            case .array(let arrayValue):
                tags[key] = formatNumberArray(arrayValue)
                switch key {
                case "0020,0037":
                    if arrayValue.count == 6 {
                        row = Array(arrayValue.prefix(3))
                        column = Array(arrayValue.suffix(3))
                    }
                case "0020,0032":
                    if arrayValue.count >= 3 {
                        position = Array(arrayValue.prefix(3))
                    }
                case "0028,1050":
                    windowCenter = arrayValue
                case "0028,1051":
                    windowWidth = arrayValue
                case "0028,0030":
                    if arrayValue.count >= 2 {
                        pixelSpacing = CIPixelSpacing(row: arrayValue[0], column: arrayValue[1])
                    }
                default:
                    break
                }
            case .boolean(let boolValue):
                tags[key] = boolValue ? "true" : "false"
                switch key {
                case "_orientationConsistent":
                    consistent = boolValue
                case "_pixelDataConsistent":
                    pixelDataConsistentAcrossSlices = boolValue
                case "_geometryConsistent":
                    geometryConsistentAcrossSlices = boolValue
                default:
                    break
                }
            }
        }

        return ParsedMetadata(
            tags: tags,
            imageOrientationPatientRow: row,
            imageOrientationPatientColumn: column,
            imagePositionPatient: position,
            imageOrientationConsistentAcrossSlices: consistent,
            pixelDataConsistentAcrossSlices: pixelDataConsistentAcrossSlices,
            geometryConsistentAcrossSlices: geometryConsistentAcrossSlices,
            seriesNumber: seriesNumber,
            instanceNumber: instanceNumber,
            bitsAllocated: bitsAllocated,
            bitsStored: bitsStored,
            highBit: highBit,
            pixelRepresentation: pixelRepresentation,
            rescaleIntercept: rescaleIntercept,
            rescaleSlope: rescaleSlope,
            windowCenter: windowCenter,
            windowWidth: windowWidth,
            rows: rows,
            columns: columns,
            sliceThickness: sliceThickness,
            spacingBetweenSlices: spacingBetweenSlices,
            pixelSpacing: pixelSpacing,
            transferSyntaxUID: transferSyntaxUID,
            numberOfFrames: numberOfFrames,
            numberOfInstances: numberOfInstances
        )
    }

    private func formatNumber(_ value: Double) -> String {
        var text = String(format: "%.6f", value)
        while text.contains(".") && text.last == "0" {
            text.removeLast()
        }
        if text.last == "." {
            text.removeLast()
        }
        if text.isEmpty {
            return "0"
        }
        return text
    }

    private func formatNumberArray(_ values: [Double]) -> String {
        values.map { formatNumber($0) }.joined(separator: "\\")
    }

    func parseInt(_ value: String?) -> Int? {
        guard let value else { return nil }
        return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func parseDouble(_ value: String?) -> Double? {
        guard let value else { return nil }
        return Double(value.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func parsePixelSpacing(_ value: String?) -> CIPixelSpacing? {
        guard let value else { return nil }
        let components = value
            .replacingOccurrences(of: ",", with: "\\")
            .split(separator: "\\")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        guard components.count >= 2,
              let row = Double(components[0]),
              let column = Double(components[1]) else {
            return nil
        }
        return CIPixelSpacing(row: row, column: column)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
