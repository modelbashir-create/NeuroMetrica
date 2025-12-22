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
        self.additionalTags = additionalTags
    }
}
