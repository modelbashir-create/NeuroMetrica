//
//  CIMetadata.swift
//  ChromaEngineKit
//
//  Normalized, engine-level metadata for a loaded volume.
//
//  - Keeps PHI / header details out of low-level ITK glue.
//  - Aggregates common DICOM / NIfTI / NRRD fields into a single struct.
//  - Stores raw tag map for advanced viewers / dev tools.
//

import Foundation

/// Source format for the metadata / volume.
/// This is a logical classification, not tied to a specific file extension.
public enum CIMetadataSourceFormat: String, Sendable {
    case dicom
    case nifti
    case nrrd
    case other
    case unknown
}

/// Pixel spacing in mm (row, column) for convenience.
public struct CIPixelSpacing: Sendable, Equatable {
    public var row: Double
    public var column: Double

    public init(row: Double, column: Double) {
        self.row = row
        self.column = column
    }
}

/// Canonical metadata model for a volume in the engine.
///
/// All fields are optional because different formats expose different subsets.
/// DICOM-heavy fields are included but safe for NIfTI / NRRD (they just stay nil).
public struct CIMetadata: Sendable, Equatable {

    // MARK: - Source information

    /// Logical source format (DICOM / NIfTI / NRRD / Other).
    public var sourceFormat: CIMetadataSourceFormat

    /// Optional description of where this volume came from (e.g. file path or series description).
    /// Intended for logging / debugging, not for UI PHI display.
    public var sourceDescription: String?

    // MARK: - Patient

    public var patientID: String?
    public var patientName: String?
    public var patientSex: String?
    public var patientBirthDate: String?   // Raw DICOM or normalized string
    public var patientAge: String?

    // MARK: - Study / Series

    public var studyInstanceUID: String?
    public var seriesInstanceUID: String?
    public var frameOfReferenceUID: String?

    public var studyID: String?
    public var accessionNumber: String?

    public var studyDescription: String?
    public var seriesDescription: String?
    public var modality: String?
    public var bodyPartExamined: String?

    public var studyDate: String?
    public var studyTime: String?
    public var seriesNumber: Int?
    public var instanceNumber: Int?

    // MARK: - Institution / Equipment

    public var institutionName: String?
    public var manufacturer: String?
    public var manufacturerModelName: String?

    // MARK: - Acquisition timing

    /// Typically a DICOM-style date string (YYYYMMDD) or normalized variant.
    public var acquisitionDate: String?

    /// Typically a DICOM-style time string (HHMMSS.frac) or normalized variant.
    public var acquisitionTime: String?

    /// Convenience concatenation of date + time when both are available.
    public var acquisitionDateTime: String? {
        if let date = acquisitionDate, let time = acquisitionTime {
            return "\(date) \(time)"
        }
        return acquisitionDate ?? acquisitionTime
    }

    // MARK: - Geometry / Resolution

    public var rows: Int?
    public var columns: Int?

    /// Slice thickness in mm, if available.
    public var sliceThickness: Double?

    /// Distance between slice centers in mm, if available.
    public var spacingBetweenSlices: Double?

    /// In-plane pixel spacing (row, column) in mm.
    public var pixelSpacing: CIPixelSpacing?
    public var bitsAllocated: Int?
    public var bitsStored: Int?
    public var pixelRepresentation: Int?
    public var highBit: Int?
    public var rescaleIntercept: Double?
    public var rescaleSlope: Double?
    public var windowCenter: [Double]?
    public var windowWidth: [Double]?
    public var transferSyntaxUID: String?
    public var pixelDataConsistentAcrossSlices: Bool?
    public var geometryConsistentAcrossSlices: Bool?
    public var numberOfFrames: Int?
    public var numberOfInstances: Int?

    // MARK: - DICOM Orientation (Patient)

    /// Image Orientation (Patient) row direction cosines.
    public var imageOrientationPatientRow: [Double]?

    /// Image Orientation (Patient) column direction cosines.
    public var imageOrientationPatientColumn: [Double]?

    /// Image Position (Patient) of the first slice.
    public var imagePositionPatient: [Double]?

    /// Whether orientation was consistent across slices (when validated).
    public var imageOrientationConsistentAcrossSlices: Bool?

    // MARK: - Per-slice provenance

    /// Raw per-slice provenance captured at load time (not UI-facing).
    public var sliceProvenance: [CISliceProvenance]?

    /// Mapping from ordered slice index to raw provenance index.
    /// This preserves raw read order while allowing ordered access.
    public var sliceOrderToRawIndex: [Int]?

    /// Indicates if slice spacing is uniform within tolerance.
    public var spacingUniform: Bool?

    /// Reference slice spacing derived from ordered IPP distances (mm).
    public var spacingReferenceMm: Double?

    /// Maximum spacing error observed relative to reference spacing (mm).
    public var maxSpacingErrorMm: Double?

    /// Indicates if ImageOrientationPatient was consistent across slices.
    public var orientationConsistent: Bool?

    /// Indicates if the direction matrix is left-handed.
    public var leftHandedDirection: Bool?

    /// Indicates if the source was a multi-frame DICOM object.
    public var multiFrameDetected: Bool?

    /// Human-readable warning about multi-frame detection.
    public var multiFrameWarning: String?

    // MARK: - Series diagnostics

    public var seriesDiagnostics: [CISeriesDiagnostic]?
    public var subseriesDiagnostics: [CISubseriesDiagnostic]?
    public var selectedSeriesInfo: CISelectedSeriesInfo?
    public var seriesCandidates: [SeriesCandidateMetadata]?
    public var selectedSeriesCandidateId: String?
    public var seriesSelectionReason: String?
    public var seriesSelectionInfo: SeriesSelectionInfo?
    public var geometryValidation: CIGeometryValidation?

    // MARK: - Raw tags / header map

    /// Raw header / tag map for advanced consumers and dev tools.
    ///
    /// For DICOM, keys are typically "gggg,eeee" (e.g. "0010,0010" for PatientName).
    /// For NIfTI / NRRD, keys can be header field names.
    public var additionalTags: [String: String]

    // MARK: - Computed helpers

    /// Simple heuristic for whether this record looks anonymized.
    /// (Not a guarantee; intended for UI hints / dev diagnostics only.)
    public var isAnonymized: Bool {
        let idEmpty = (patientID ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let nameEmpty = (patientName ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let accessionEmpty = (accessionNumber ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return idEmpty && nameEmpty && accessionEmpty
    }

    // MARK: - Initializer

    public init(
        sourceFormat: CIMetadataSourceFormat = .unknown,
        sourceDescription: String? = nil,
        patientID: String? = nil,
        patientName: String? = nil,
        patientSex: String? = nil,
        patientBirthDate: String? = nil,
        patientAge: String? = nil,
        studyInstanceUID: String? = nil,
        seriesInstanceUID: String? = nil,
        frameOfReferenceUID: String? = nil,
        studyID: String? = nil,
        accessionNumber: String? = nil,
        studyDescription: String? = nil,
        seriesDescription: String? = nil,
        modality: String? = nil,
        bodyPartExamined: String? = nil,
        studyDate: String? = nil,
        studyTime: String? = nil,
        seriesNumber: Int? = nil,
        instanceNumber: Int? = nil,
        institutionName: String? = nil,
        manufacturer: String? = nil,
        manufacturerModelName: String? = nil,
        acquisitionDate: String? = nil,
        acquisitionTime: String? = nil,
        rows: Int? = nil,
        columns: Int? = nil,
        sliceThickness: Double? = nil,
        spacingBetweenSlices: Double? = nil,
        pixelSpacing: CIPixelSpacing? = nil,
        bitsAllocated: Int? = nil,
        bitsStored: Int? = nil,
        pixelRepresentation: Int? = nil,
        highBit: Int? = nil,
        rescaleIntercept: Double? = nil,
        rescaleSlope: Double? = nil,
        windowCenter: [Double]? = nil,
        windowWidth: [Double]? = nil,
        transferSyntaxUID: String? = nil,
        pixelDataConsistentAcrossSlices: Bool? = nil,
        geometryConsistentAcrossSlices: Bool? = nil,
        numberOfFrames: Int? = nil,
        numberOfInstances: Int? = nil,
        imageOrientationPatientRow: [Double]? = nil,
        imageOrientationPatientColumn: [Double]? = nil,
        imagePositionPatient: [Double]? = nil,
        imageOrientationConsistentAcrossSlices: Bool? = nil,
        sliceProvenance: [CISliceProvenance]? = nil,
        sliceOrderToRawIndex: [Int]? = nil,
        spacingUniform: Bool? = nil,
        spacingReferenceMm: Double? = nil,
        maxSpacingErrorMm: Double? = nil,
        orientationConsistent: Bool? = nil,
        leftHandedDirection: Bool? = nil,
        multiFrameDetected: Bool? = nil,
        multiFrameWarning: String? = nil,
        seriesDiagnostics: [CISeriesDiagnostic]? = nil,
        subseriesDiagnostics: [CISubseriesDiagnostic]? = nil,
        selectedSeriesInfo: CISelectedSeriesInfo? = nil,
        seriesCandidates: [SeriesCandidateMetadata]? = nil,
        selectedSeriesCandidateId: String? = nil,
        seriesSelectionReason: String? = nil,
        seriesSelectionInfo: SeriesSelectionInfo? = nil,
        geometryValidation: CIGeometryValidation? = nil,
        additionalTags: [String: String] = [:]
    ) {
        self.sourceFormat = sourceFormat
        self.sourceDescription = sourceDescription
        self.patientID = patientID
        self.patientName = patientName
        self.patientSex = patientSex
        self.patientBirthDate = patientBirthDate
        self.patientAge = patientAge
        self.studyInstanceUID = studyInstanceUID
        self.seriesInstanceUID = seriesInstanceUID
        self.frameOfReferenceUID = frameOfReferenceUID
        self.studyID = studyID
        self.accessionNumber = accessionNumber
        self.studyDescription = studyDescription
        self.seriesDescription = seriesDescription
        self.modality = modality
        self.bodyPartExamined = bodyPartExamined
        self.studyDate = studyDate
        self.studyTime = studyTime
        self.seriesNumber = seriesNumber
        self.instanceNumber = instanceNumber
        self.institutionName = institutionName
        self.manufacturer = manufacturer
        self.manufacturerModelName = manufacturerModelName
        self.acquisitionDate = acquisitionDate
        self.acquisitionTime = acquisitionTime
        self.rows = rows
        self.columns = columns
        self.sliceThickness = sliceThickness
        self.spacingBetweenSlices = spacingBetweenSlices
        self.pixelSpacing = pixelSpacing
        self.bitsAllocated = bitsAllocated
        self.bitsStored = bitsStored
        self.pixelRepresentation = pixelRepresentation
        self.highBit = highBit
        self.rescaleIntercept = rescaleIntercept
        self.rescaleSlope = rescaleSlope
        self.windowCenter = windowCenter
        self.windowWidth = windowWidth
        self.transferSyntaxUID = transferSyntaxUID
        self.pixelDataConsistentAcrossSlices = pixelDataConsistentAcrossSlices
        self.geometryConsistentAcrossSlices = geometryConsistentAcrossSlices
        self.numberOfFrames = numberOfFrames
        self.numberOfInstances = numberOfInstances
        self.imageOrientationPatientRow = imageOrientationPatientRow
        self.imageOrientationPatientColumn = imageOrientationPatientColumn
        self.imagePositionPatient = imagePositionPatient
        self.imageOrientationConsistentAcrossSlices = imageOrientationConsistentAcrossSlices
        self.sliceProvenance = sliceProvenance
        self.sliceOrderToRawIndex = sliceOrderToRawIndex
        self.spacingUniform = spacingUniform
        self.spacingReferenceMm = spacingReferenceMm
        self.maxSpacingErrorMm = maxSpacingErrorMm
        self.orientationConsistent = orientationConsistent
        self.leftHandedDirection = leftHandedDirection
        self.multiFrameDetected = multiFrameDetected
        self.multiFrameWarning = multiFrameWarning
        self.seriesDiagnostics = seriesDiagnostics
        self.subseriesDiagnostics = subseriesDiagnostics
        self.selectedSeriesInfo = selectedSeriesInfo
        self.seriesCandidates = seriesCandidates
        self.selectedSeriesCandidateId = selectedSeriesCandidateId
        self.seriesSelectionReason = seriesSelectionReason
        self.seriesSelectionInfo = seriesSelectionInfo
        self.geometryValidation = geometryValidation
        self.additionalTags = additionalTags
    }
}

public struct CISeriesDiagnostic: Sendable, Equatable {
    public var seriesInstanceUID: String
    public var fileCount: Int
    public var studyDescription: String?
    public var seriesDescription: String?
    public var modality: String?
    public var seriesNumber: String?

    public init(
        seriesInstanceUID: String,
        fileCount: Int,
        studyDescription: String? = nil,
        seriesDescription: String? = nil,
        modality: String? = nil,
        seriesNumber: String? = nil
    ) {
        self.seriesInstanceUID = seriesInstanceUID
        self.fileCount = fileCount
        self.studyDescription = studyDescription
        self.seriesDescription = seriesDescription
        self.modality = modality
        self.seriesNumber = seriesNumber
    }
}

public struct CISubseriesDiagnostic: Sendable, Equatable {
    public var seriesInstanceUID: String
    public var subseriesKey: String
    public var fileCount: Int
    public var confidence: Int
    public var orientationConsistent: Bool?
    public var spacingUniform: Bool?
    public var spacingReferenceMm: Double?
    public var maxSpacingErrorMm: Double?
    public var reasons: [String]

    public init(
        seriesInstanceUID: String,
        subseriesKey: String,
        fileCount: Int,
        confidence: Int,
        orientationConsistent: Bool? = nil,
        spacingUniform: Bool? = nil,
        spacingReferenceMm: Double? = nil,
        maxSpacingErrorMm: Double? = nil,
        reasons: [String] = []
    ) {
        self.seriesInstanceUID = seriesInstanceUID
        self.subseriesKey = subseriesKey
        self.fileCount = fileCount
        self.confidence = confidence
        self.orientationConsistent = orientationConsistent
        self.spacingUniform = spacingUniform
        self.spacingReferenceMm = spacingReferenceMm
        self.maxSpacingErrorMm = maxSpacingErrorMm
        self.reasons = reasons
    }
}

public struct SeriesCandidateMetadata: Sendable, Equatable {
    public var candidateId: String
    public var sliceCount: Int
    public var groupingKeys: [String]
    public var orderingMethod: String?
    public var rejectionReason: String?

    public init(
        candidateId: String,
        sliceCount: Int,
        groupingKeys: [String],
        orderingMethod: String? = nil,
        rejectionReason: String? = nil
    ) {
        self.candidateId = candidateId
        self.sliceCount = sliceCount
        self.groupingKeys = groupingKeys
        self.orderingMethod = orderingMethod
        self.rejectionReason = rejectionReason
    }
}

public struct SeriesSelectionInfo: Sendable, Equatable {
    public var candidateId: String
    public var sliceCount: Int
    public var orderingMethod: String?
    public var groupingKeysUsed: [String]
    public var fallbackUsed: Bool
    public var selectionReason: String

    public init(
        candidateId: String,
        sliceCount: Int,
        orderingMethod: String? = nil,
        groupingKeysUsed: [String],
        fallbackUsed: Bool,
        selectionReason: String
    ) {
        self.candidateId = candidateId
        self.sliceCount = sliceCount
        self.orderingMethod = orderingMethod
        self.groupingKeysUsed = groupingKeysUsed
        self.fallbackUsed = fallbackUsed
        self.selectionReason = selectionReason
    }
}

public struct CIGeometryValidation: Sendable, Equatable {
    public var sliceOrder: String
    public var spacingUniform: Bool
    public var spacingMin: Double
    public var spacingMax: Double
    public var directionOrthonormal: Bool
    public var directionDeterminant: Double
    public var leftHanded: Bool
    public var usedDefaults: Bool
    public var validationStatus: String

    public init(
        sliceOrder: String,
        spacingUniform: Bool,
        spacingMin: Double,
        spacingMax: Double,
        directionOrthonormal: Bool,
        directionDeterminant: Double,
        leftHanded: Bool,
        usedDefaults: Bool,
        validationStatus: String
    ) {
        self.sliceOrder = sliceOrder
        self.spacingUniform = spacingUniform
        self.spacingMin = spacingMin
        self.spacingMax = spacingMax
        self.directionOrthonormal = directionOrthonormal
        self.directionDeterminant = directionDeterminant
        self.leftHanded = leftHanded
        self.usedDefaults = usedDefaults
        self.validationStatus = validationStatus
    }
}

public struct CISelectedSeriesInfo: Sendable, Equatable {
    public var seriesInstanceUID: String
    public var subseriesKey: String?
    public var confidence: Int

    public init(seriesInstanceUID: String, subseriesKey: String? = nil, confidence: Int) {
        self.seriesInstanceUID = seriesInstanceUID
        self.subseriesKey = subseriesKey
        self.confidence = confidence
    }
}
