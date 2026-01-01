//
//  ChromaEngine+Metadata.swift
//  ChromaEngineKit
//

import Foundation
import ChromaImagingCore

// MARK: - Metadata

extension ChromaEngine {

    func buildMetadata(
        from descriptor: ITKImageDescriptor,
        sourceFormat: CIMetadataSourceFormat,
        sourceDescription: String?
    ) -> CIMetadata {
        let parsed = parseMetadataMap(descriptor.metadata)
        let seriesDiagnostics = parseSeriesDiagnostics(from: descriptor.metadataJSON)
        let geometryValidation = parseGeometryValidation(from: descriptor.metadataJSON)
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
            sliceProvenance: parseSliceProvenanceJSON(descriptor.sliceProvenanceJSON),
            sliceOrderToRawIndex: parsed.sliceOrderToRawIndex,
            spacingUniform: parsed.spacingUniform,
            spacingReferenceMm: parsed.spacingReferenceMm,
            maxSpacingErrorMm: parsed.maxSpacingErrorMm,
            orientationConsistent: parsed.orientationConsistent,
            leftHandedDirection: parsed.leftHandedDirection,
            multiFrameDetected: parsed.multiFrameDetected,
            multiFrameWarning: parsed.multiFrameWarning,
            seriesDiagnostics: seriesDiagnostics.series,
            subseriesDiagnostics: seriesDiagnostics.subseries,
            selectedSeriesInfo: seriesDiagnostics.selected,
            seriesCandidates: seriesDiagnostics.candidates,
            selectedSeriesCandidateId: seriesDiagnostics.selectedCandidateId,
            seriesSelectionReason: seriesDiagnostics.selectionReason,
            seriesSelectionInfo: seriesDiagnostics.selectionInfo,
            geometryValidation: geometryValidation,
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
        var sliceOrderToRawIndex: [Int]?
        var spacingUniform: Bool?
        var spacingReferenceMm: Double?
        var maxSpacingErrorMm: Double?
        var orientationConsistent: Bool?
        var leftHandedDirection: Bool?
        var multiFrameDetected: Bool?
        var multiFrameWarning: String?
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

}

// MARK: - Private helpers

private extension ChromaEngine {

    func parseMetadataMap(_ metadata: [String: ITKMetadataValue]) -> ParsedMetadata {
        var tags: [String: String] = [:]
        var row: [Double]?
        var column: [Double]?
        var position: [Double]?
        var consistent: Bool?
        var orientationConsistentFlag: Bool?
        var spacingUniform: Bool?
        var spacingReferenceMm: Double?
        var maxSpacingErrorMm: Double?
        var sliceOrderToRawIndex: [Int]?
        var leftHandedDirection: Bool?
        var multiFrameDetected: Bool?
        var multiFrameWarning: String?
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
                case "_multiFrameWarning":
                    multiFrameWarning = stringValue
                default:
                    break
                }
            case .number(let numberValue):
                tags[key] = formatNumber(numberValue)
                switch key {
                case "_spacingReference":
                    spacingReferenceMm = numberValue
                case "_spacingMaxError":
                    maxSpacingErrorMm = numberValue
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
                case "_sliceOrder":
                    sliceOrderToRawIndex = arrayValue.map { Int($0.rounded()) }
                default:
                    break
                }
            case .boolean(let boolValue):
                tags[key] = boolValue ? "true" : "false"
                switch key {
                case "_orientationConsistent":
                    consistent = boolValue
                    orientationConsistentFlag = boolValue
                case "_spacingUniform":
                    spacingUniform = boolValue
                case "_leftHanded":
                    leftHandedDirection = boolValue
                case "_multiFrame":
                    multiFrameDetected = boolValue
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
            sliceOrderToRawIndex: sliceOrderToRawIndex,
            spacingUniform: spacingUniform,
            spacingReferenceMm: spacingReferenceMm,
            maxSpacingErrorMm: maxSpacingErrorMm,
            orientationConsistent: orientationConsistentFlag,
            leftHandedDirection: leftHandedDirection,
            multiFrameDetected: multiFrameDetected,
            multiFrameWarning: multiFrameWarning,
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

    func parseSliceProvenanceJSON(_ json: String?) -> [CISliceProvenance]? {
        guard let json,
              let data = json.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data, options: []) as? [Any] else {
            return nil
        }

        var results: [CISliceProvenance] = []
        results.reserveCapacity(array.count)

        var missingUID = 0
        var missingNumber = 0
        var missingIPP = 0
        var missingIOP = 0

        for entry in array {
            guard let dict = entry as? [String: Any] else {
                results.append(CISliceProvenance())
                missingUID += 1
                missingNumber += 1
                missingIPP += 1
                missingIOP += 1
                continue
            }

            let instanceUID = dict["instanceUID"] as? String

            let instanceNumber: Int?
            if let number = dict["instanceNumber"] as? NSNumber {
                instanceNumber = number.intValue
            } else if let numberString = dict["instanceNumber"] as? String,
                      let number = Int(numberString.trimmingCharacters(in: .whitespacesAndNewlines)) {
                instanceNumber = number
            } else {
                instanceNumber = nil
            }

            let ipp = parseNumberArray(dict["imagePositionPatient"])
            let iop = parseNumberArray(dict["imageOrientationPatient"])

            if instanceUID == nil { missingUID += 1 }
            if instanceNumber == nil { missingNumber += 1 }
            if ipp == nil { missingIPP += 1 }
            if iop == nil { missingIOP += 1 }

            results.append(CISliceProvenance(
                instanceUID: instanceUID,
                instanceNumber: instanceNumber,
                imagePositionPatient: ipp,
                imageOrientationPatient: iop
            ))
        }

        if missingUID > 0 || missingNumber > 0 || missingIPP > 0 || missingIOP > 0 {
            NSLog("ChromaEngine: slice provenance missing fields (uid=%d, number=%d, ipp=%d, iop=%d, total=%d)",
                  missingUID, missingNumber, missingIPP, missingIOP, results.count)
        }

        return results
    }

    func parseNumberArray(_ value: Any?) -> [Double]? {
        if let numbers = value as? [NSNumber] {
            return numbers.map { $0.doubleValue }
        }
        if let numbers = value as? [Double] {
            return numbers
        }
        return nil
    }
}

// MARK: - Series Diagnostics

extension ChromaEngine {

    struct SeriesDiagnosticsParseResult {
        var series: [CISeriesDiagnostic]?
        var subseries: [CISubseriesDiagnostic]?
        var selected: CISelectedSeriesInfo?
        var candidates: [SeriesCandidateMetadata]?
        var selectedCandidateId: String?
        var selectionReason: String?
        var selectionInfo: SeriesSelectionInfo?
    }

    func parseSeriesDiagnostics(from metadataJSON: String?) -> SeriesDiagnosticsParseResult {
        guard let metadataJSON,
              let data = metadataJSON.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: []),
              let dict = object as? [String: Any] else {
            return SeriesDiagnosticsParseResult()
        }

        let series = parseSeriesDiagnosticsArray(dict["_seriesDiagnostics"])
        let subseries = parseSubseriesDiagnosticsArray(dict["_subseriesDiagnostics"])
        let selected = parseSelectedSeriesInfo(dict["_selectedSeriesInfo"])
        let candidates = parseSeriesCandidates(dict["_seriesCandidates"])
        let selectedCandidateId = dict["_selectedSeriesCandidateId"] as? String
        let selectionReason = dict["_seriesSelectionReason"] as? String
        let selectionInfo = parseSeriesSelectionInfo(dict["_selectedSeriesCandidateInfo"])

        return SeriesDiagnosticsParseResult(
            series: series,
            subseries: subseries,
            selected: selected,
            candidates: candidates,
            selectedCandidateId: selectedCandidateId,
            selectionReason: selectionReason,
            selectionInfo: selectionInfo
        )
    }

    func parseSeriesDiagnosticsArray(_ value: Any?) -> [CISeriesDiagnostic]? {
        guard let array = value as? [Any] else { return nil }
        var results: [CISeriesDiagnostic] = []
        for entry in array {
            guard let dict = entry as? [String: Any],
                  let uid = dict["seriesInstanceUID"] as? String else { continue }
            let fileCount = (dict["fileCount"] as? NSNumber)?.intValue ?? 0
            results.append(CISeriesDiagnostic(seriesInstanceUID: uid, fileCount: fileCount))
        }
        return results.isEmpty ? nil : results
    }

    func parseSubseriesDiagnosticsArray(_ value: Any?) -> [CISubseriesDiagnostic]? {
        guard let array = value as? [Any] else { return nil }
        var results: [CISubseriesDiagnostic] = []
        for entry in array {
            guard let dict = entry as? [String: Any],
                  let uid = dict["seriesInstanceUID"] as? String,
                  let key = dict["subseriesKey"] as? String else { continue }
            let fileCount = (dict["fileCount"] as? NSNumber)?.intValue ?? 0
            let confidence = (dict["confidence"] as? NSNumber)?.intValue ?? 0
            let orientationConsistent = dict["orientationConsistent"] as? Bool
            let spacingUniform = dict["spacingUniform"] as? Bool
            let spacingReference = (dict["spacingReferenceMm"] as? NSNumber)?.doubleValue
            let maxSpacingError = (dict["maxSpacingErrorMm"] as? NSNumber)?.doubleValue
            let reasons = dict["reasons"] as? [String] ?? []

            results.append(CISubseriesDiagnostic(
                seriesInstanceUID: uid,
                subseriesKey: key,
                fileCount: fileCount,
                confidence: confidence,
                orientationConsistent: orientationConsistent,
                spacingUniform: spacingUniform,
                spacingReferenceMm: spacingReference,
                maxSpacingErrorMm: maxSpacingError,
                reasons: reasons
            ))
        }
        return results.isEmpty ? nil : results
    }

    func parseSelectedSeriesInfo(_ value: Any?) -> CISelectedSeriesInfo? {
        guard let dict = value as? [String: Any],
              let uid = dict["seriesInstanceUID"] as? String else {
            return nil
        }
        let key = dict["subseriesKey"] as? String
        let confidence = (dict["confidence"] as? NSNumber)?.intValue ?? 0
        return CISelectedSeriesInfo(seriesInstanceUID: uid, subseriesKey: key, confidence: confidence)
    }

    func parseSeriesCandidates(_ value: Any?) -> [SeriesCandidateMetadata]? {
        guard let array = value as? [Any] else { return nil }
        var results: [SeriesCandidateMetadata] = []
        for entry in array {
            guard let dict = entry as? [String: Any],
                  let candidateId = dict["candidateId"] as? String else { continue }
            let sliceCount = (dict["sliceCount"] as? NSNumber)?.intValue ?? 0
            let groupingKeys = dict["groupingKeys"] as? [String] ?? []
            let orderingMethod = dict["orderingMethod"] as? String
            let rejectionReason = dict["rejectionReason"] as? String
            results.append(SeriesCandidateMetadata(
                candidateId: candidateId,
                sliceCount: sliceCount,
                groupingKeys: groupingKeys,
                orderingMethod: orderingMethod,
                rejectionReason: rejectionReason
            ))
        }
        return results.isEmpty ? nil : results
    }

    func parseSeriesSelectionInfo(_ value: Any?) -> SeriesSelectionInfo? {
        guard let dict = value as? [String: Any],
              let candidateId = dict["candidateId"] as? String else {
            return nil
        }
        let sliceCount = (dict["sliceCount"] as? NSNumber)?.intValue ?? 0
        let orderingMethod = dict["orderingMethod"] as? String
        let groupingKeysUsed = dict["groupingKeysUsed"] as? [String] ?? []
        let fallbackUsed = dict["fallbackUsed"] as? Bool ?? false
        let selectionReason = dict["selectionReason"] as? String ?? ""
        return SeriesSelectionInfo(
            candidateId: candidateId,
            sliceCount: sliceCount,
            orderingMethod: orderingMethod,
            groupingKeysUsed: groupingKeysUsed,
            fallbackUsed: fallbackUsed,
            selectionReason: selectionReason
        )
    }

    func parseGeometryValidation(from metadataJSON: String?) -> CIGeometryValidation? {
        guard let metadataJSON,
              let data = metadataJSON.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: []),
              let dict = object as? [String: Any],
              let validation = dict["_geometryValidation"] as? [String: Any] else {
            return nil
        }

        let sliceOrder = validation["sliceOrder"] as? String ?? "incomplete"
        let spacing = validation["spacing"] as? [String: Any]
        let spacingUniform = spacing?["uniform"] as? Bool ?? false
        let spacingMin = (spacing?["min"] as? NSNumber)?.doubleValue ?? 0.0
        let spacingMax = (spacing?["max"] as? NSNumber)?.doubleValue ?? 0.0

        let direction = validation["direction"] as? [String: Any]
        let directionOrthonormal = direction?["orthonormal"] as? Bool ?? false
        let directionDeterminant = (direction?["determinant"] as? NSNumber)?.doubleValue ?? 0.0
        let leftHanded = direction?["leftHanded"] as? Bool ?? false

        let usedDefaults = validation["usedDefaults"] as? Bool ?? false
        let validationStatus = validation["validationStatus"] as? String ?? "warning"

        return CIGeometryValidation(
            sliceOrder: sliceOrder,
            spacingUniform: spacingUniform,
            spacingMin: spacingMin,
            spacingMax: spacingMax,
            directionOrthonormal: directionOrthonormal,
            directionDeterminant: directionDeterminant,
            leftHanded: leftHanded,
            usedDefaults: usedDefaults,
            validationStatus: validationStatus
        )
    }
}
