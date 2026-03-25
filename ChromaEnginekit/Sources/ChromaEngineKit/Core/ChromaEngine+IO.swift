//
//  ChromaEngine+IO.swift
//  ChromaEngineKit
//

import Foundation
import ChromaImagingCore

// MARK: - IO

extension ChromaEngine {

    /// Load an NRRD volume from disk.
    ///
    /// Long-term: delegate to ITKImageIO / ITK bridge in
    /// ChromaImagingCore.
    public func loadNRRDVolume(from url: URL) async throws -> EngineVolumeDescriptor {
        try loadSingleFileVolume(from: url, sourceFormat: .nrrd)
    }

    /// Load a single-file DICOM volume (e.g., Secondary Capture).
    public func loadDicomFile(from url: URL) async throws -> EngineVolumeDescriptor {
        try loadSingleFileVolume(from: url, sourceFormat: .dicom)
    }
}

// MARK: - Private helpers

extension ChromaEngine {

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
        var metadata = buildMetadata(from: descriptor, sourceFormat: sourceFormat, sourceDescription: sourceDescription)
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
            rescaleSlope: metadata.rescaleSlope ?? 1.0,
            rescaleIntercept: metadata.rescaleIntercept ?? 0.0,
            voxelData: data
        )

        let leftHanded = metadata.leftHandedDirection ?? isLeftHandedDirection(volume: volume)
        metadata.leftHandedDirection = leftHanded
        if leftHanded {
            NSLog("ChromaEngine: left-handed direction matrix detected.")
        }

        if metadata.orientationConsistent == false || metadata.spacingUniform == false {
            NSLog("ChromaEngine: slice geometry warnings (orientation=%d, spacing=%d).",
                  metadata.orientationConsistent == true ? 1 : 0,
                  metadata.spacingUniform == true ? 1 : 0)
        }

        logGeometryValidationIfNeeded(metadata: metadata, volume: volume)
        validateDirectionMatrix(volume: volume)

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
}
