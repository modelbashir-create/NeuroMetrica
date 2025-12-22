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
        let components = max(volume.componentsPerPixel, 1)

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

        let outputCount = width * height
        var output = Data(count: outputCount)

        let lower = level - window / 2
        let upper = level + window / 2
        let range = max(upper - lower, 1)

        output.withUnsafeMutableBytes { outPtr in
            guard let outBytes = outPtr.bindMemory(to: UInt8.self).baseAddress else { return }

            volume.voxelData.withUnsafeBytes { inPtr in
                guard let base = inPtr.baseAddress else { return }
                for y in 0..<height {
                    for x in 0..<width {
                        let voxelIndex: Int
                        switch orientation {
                        case .axial:
                            voxelIndex = ((clampedIndex * sizeY + y) * sizeX + x) * components
                        case .coronal:
                            voxelIndex = ((y * sizeY + clampedIndex) * sizeX + x) * components
                        case .sagittal:
                            voxelIndex = ((y * sizeY + x) * sizeX + clampedIndex) * components
                        }

                        let value: Float
                        switch volume.componentType {
                        case .uint8:
                            value = Float(base.advanced(by: voxelIndex * volume.bytesPerComponent).load(as: UInt8.self))
                        case .uint16:
                            value = Float(base.advanced(by: voxelIndex * volume.bytesPerComponent).load(as: UInt16.self))
                        case .int16:
                            value = Float(base.advanced(by: voxelIndex * volume.bytesPerComponent).load(as: Int16.self))
                        case .float32:
                            value = base.advanced(by: voxelIndex * volume.bytesPerComponent).load(as: Float.self)
                        }

                        let normalized = min(max((value - lower) / range, 0), 1)
                        let outputValue = UInt8(normalized * 255)
                        outBytes[y * width + x] = outputValue
                    }
                }
            }
        }

        return CIImage2D(
            width: width,
            height: height,
            componentsPerPixel: 1,
            componentType: .uint8,
            bytesPerComponent: 1,
            bytesPerRow: width,
            orientation: orientation,
            sliceIndex: clampedIndex,
            data: output
        )
    }

    func buildMetadata(
        from descriptor: ITKImageDescriptor,
        sourceFormat: CIMetadataSourceFormat,
        sourceDescription: String?
    ) -> CIMetadata {
        let tags = parseMetadataTags(descriptor.metadataJSON)
        let metadata = CIMetadata(
            sourceFormat: sourceFormat,
            sourceDescription: sourceDescription,
            patientID: tags["0010,0020"],
            patientName: tags["0010,0010"],
            patientSex: tags["0010,0040"],
            patientBirthDate: tags["0010,0030"],
            patientAge: tags["0010,1010"],
            studyInstanceUID: tags["0020,000D"],
            seriesInstanceUID: tags["0020,000E"],
            frameOfReferenceUID: tags["0020,0052"],
            studyID: tags["0020,0010"],
            accessionNumber: tags["0008,0050"],
            studyDescription: tags["0008,1030"],
            seriesDescription: tags["0008,103E"],
            modality: tags["0008,0060"],
            bodyPartExamined: tags["0018,0015"],
            institutionName: tags["0008,0080"],
            manufacturer: tags["0008,0070"],
            manufacturerModelName: tags["0008,1090"],
            acquisitionDate: tags["0008,0022"] ?? tags["0008,0021"] ?? tags["0008,0020"],
            acquisitionTime: tags["0008,0032"] ?? tags["0008,0031"] ?? tags["0008,0030"],
            rows: parseInt(tags["0028,0010"]),
            columns: parseInt(tags["0028,0011"]),
            sliceThickness: parseDouble(tags["0018,0050"]),
            spacingBetweenSlices: parseDouble(tags["0018,0088"]),
            pixelSpacing: parsePixelSpacing(tags["0028,0030"]),
            additionalTags: tags
        )

        return metadata
    }

    func parseMetadataTags(_ metadataJSON: String?) -> [String: String] {
        guard let metadataJSON,
              let data = metadataJSON.data(using: .utf8) else {
            return [:]
        }

        let object = try? JSONSerialization.jsonObject(with: data, options: [])
        return object as? [String: String] ?? [:]
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
