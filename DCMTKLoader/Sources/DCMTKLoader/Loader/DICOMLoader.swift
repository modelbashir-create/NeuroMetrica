//
//  DICOMLoader.swift
//  DCMTKLoader
//
//  Swift-facing API that bridges to DCMTK via DicomBridge.
//

import Foundation
import DCMTKLoaderObjC

public enum DICOMLoaderError: Error {
    case noFiles
    case loadFailed
    case invalidDimensions
    case allocationFailed
    case unknown(code: Int32)
}

public enum DICOMLoader {
    /// Loads a directory of DICOM instances and returns a flattened z–y–x float buffer.
    /// - Parameter url: Directory containing one DICOM series.
    /// - Returns: `DICOMVolumeExport` with voxel data and rich metadata.
    public static func loadSeries(at url: URL) throws -> DICOMVolumeExport {
        var volumePointer: UnsafeMutablePointer<NM_DicomVolume>? = nil
        let status: NM_DicomError = url.path.withCString { pathPointer in
            nm_dicom_load_series(pathPointer, &volumePointer)
        }

        guard status == NM_DicomErrorNone else {
            throw mapError(status: status)
        }

        guard let volumePointer else {
            throw DICOMLoaderError.loadFailed
        }
        let volume = volumePointer.pointee

        defer {
            nm_dicom_free(volumePointer)
        }

        guard volume.width > 0, volume.height > 0, volume.depth > 0 else {
            throw DICOMLoaderError.invalidDimensions
        }

        let voxelCount = Int(volume.width) * Int(volume.height) * Int(volume.depth)
        let buffer = UnsafeBufferPointer(start: volume.voxels, count: voxelCount)
        let voxels = Array(buffer)

        let metadata = metadataFromVolume(volume)

        return DICOMVolumeExport(
            voxels: voxels,
            width: Int(volume.width),
            height: Int(volume.height),
            depth: Int(volume.depth),
            spacing: (volume.spacingX, volume.spacingY, volume.spacingZ),
            metadata: metadata
        )
    }

    private static func metadataFromVolume(_ volume: NM_DicomVolume) -> DICOMMetadata {
        let orientation = [volume.orientation.0, volume.orientation.1, volume.orientation.2, volume.orientation.3, volume.orientation.4, volume.orientation.5]
        let position = [volume.position.0, volume.position.1, volume.position.2]

        let windowCenters: [Double]
        let windowWidths: [Double]
        if volume.windowCount > 0, let centersPointer = volume.windowCenters, let widthsPointer = volume.windowWidths {
            windowCenters = Array(UnsafeBufferPointer(start: centersPointer, count: Int(volume.windowCount)))
            windowWidths = Array(UnsafeBufferPointer(start: widthsPointer, count: Int(volume.windowCount)))
        } else {
            windowCenters = []
            windowWidths = []
        }

        let allTags = buildTagDictionary(volume: volume)

        return DICOMMetadata(
            rows: Int(volume.height),
            columns: Int(volume.width),
            numberOfSlices: Int(volume.depth),
            pixelSpacing: (Double(volume.spacingY), Double(volume.spacingX)),
            sliceThickness: Double(volume.sliceThickness),
            spacingBetweenSlices: volume.spacingBetweenSlices > 0 ? Double(volume.spacingBetweenSlices) : nil,
            imageOrientationPatient: orientation.allSatisfy { $0 == 0 } ? nil : orientation,
            imagePositionPatient: position.allSatisfy { $0 == 0 } ? nil : position,
            frameOfReferenceUID: stringIfPresent(volume.frameOfReferenceUID),
            patientName: stringIfPresent(volume.patientName),
            patientID: stringIfPresent(volume.patientID),
            patientSex: stringIfPresent(volume.patientSex),
            patientBirthDate: stringIfPresent(volume.patientBirthDate),
            studyInstanceUID: stringIfPresent(volume.studyInstanceUID),
            seriesInstanceUID: stringIfPresent(volume.seriesInstanceUID),
            studyDescription: stringIfPresent(volume.studyDescription),
            seriesDescription: stringIfPresent(volume.seriesDescription),
            modality: stringIfPresent(volume.modality),
            bitsAllocated: volume.bitsAllocated == 0 ? nil : Int(volume.bitsAllocated),
            bitsStored: volume.bitsStored == 0 ? nil : Int(volume.bitsStored),
            highBit: volume.highBit == 0 ? nil : Int(volume.highBit),
            pixelRepresentation: volume.pixelRepresentation == 0 ? nil : Int(volume.pixelRepresentation),
            photometricInterpretation: stringIfPresent(volume.photometricInterpretation),
            rescaleSlope: Double(volume.rescaleSlope),
            rescaleIntercept: Double(volume.rescaleIntercept),
            windowCenters: windowCenters,
            windowWidths: windowWidths,
            allTags: allTags
        )
    }

    private static func buildTagDictionary(volume: NM_DicomVolume) -> [String: DICOMTagValue] {
        guard volume.allTagCount > 0, let pointer = volume.allTags else { return [:] }
        var result: [String: DICOMTagValue] = [:]
        for index in 0 ..< Int(volume.allTagCount) {
            let entry = pointer[index]
            guard let keyPointer = entry.tagKey else { continue }
            let key = String(cString: keyPointer)
            switch entry.valueType {
            case NM_DicomTagValueTypeString:
                if let strPtr = entry.stringValue {
                    result[key] = .string(String(cString: strPtr))
                }
            case NM_DicomTagValueTypeInt:
                result[key] = .int(entry.intValue)
            case NM_DicomTagValueTypeDouble:
                result[key] = .double(entry.doubleValue)
            case NM_DicomTagValueTypeData:
                if let dataPtr = entry.dataValue, entry.dataLength > 0 {
                    result[key] = .data(Data(bytes: dataPtr, count: Int(entry.dataLength)))
                }
            default:
                continue
            }
        }
        return result
    }

    private static func stringIfPresent(_ pointer: UnsafePointer<CChar>?) -> String? {
        guard let pointer else { return nil }
        let value = String(cString: pointer)
        return value.isEmpty ? nil : value
    }

    private static func mapError(status: NM_DicomError) -> DICOMLoaderError {
        switch status {
        case NM_DicomErrorNone:
            return .unknown(code: status.rawValue)
        case NM_DicomErrorNoFiles:
            return .noFiles
        case NM_DicomErrorLoadFailed:
            return .loadFailed
        case NM_DicomErrorInvalidDimensions:
            return .invalidDimensions
        case NM_DicomErrorAllocationFailed:
            return .allocationFailed
        default:
            return .unknown(code: status.rawValue)
        }
    }
}
