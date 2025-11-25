//
//  DICOMMetadata.swift
//  DCMTKLoader
//
//  Rich metadata container for DICOM series.
//

import Foundation

public enum DICOMTagValue: Sendable {
    case string(String)
    case int(Int64)
    case double(Double)
    case data(Data)
}

public struct DICOMMetadata: Sendable {
    // Geometry
    public let rows: Int?
    public let columns: Int?
    public let numberOfSlices: Int?
    public let pixelSpacing: (Double, Double)? // (row, column)
    public let sliceThickness: Double?
    public let spacingBetweenSlices: Double?
    public let imageOrientationPatient: [Double]? // 6 values
    public let imagePositionPatient: [Double]? // 3 values
    public let frameOfReferenceUID: String?

    // Identity
    public let patientName: String?
    public let patientID: String?
    public let patientSex: String?
    public let patientBirthDate: String?
    public let studyInstanceUID: String?
    public let seriesInstanceUID: String?
    public let studyDescription: String?
    public let seriesDescription: String?
    public let modality: String?

    // Pixel / display
    public let bitsAllocated: Int?
    public let bitsStored: Int?
    public let highBit: Int?
    public let pixelRepresentation: Int?
    public let photometricInterpretation: String?
    public let rescaleSlope: Double?
    public let rescaleIntercept: Double?
    public let windowCenters: [Double]
    public let windowWidths: [Double]

    // General tag dictionary keyed by "gggg,eeee"
    public let allTags: [String: DICOMTagValue]

    public init(
        rows: Int?,
        columns: Int?,
        numberOfSlices: Int?,
        pixelSpacing: (Double, Double)?,
        sliceThickness: Double?,
        spacingBetweenSlices: Double?,
        imageOrientationPatient: [Double]?,
        imagePositionPatient: [Double]?,
        frameOfReferenceUID: String?,
        patientName: String?,
        patientID: String?,
        patientSex: String?,
        patientBirthDate: String?,
        studyInstanceUID: String?,
        seriesInstanceUID: String?,
        studyDescription: String?,
        seriesDescription: String?,
        modality: String?,
        bitsAllocated: Int?,
        bitsStored: Int?,
        highBit: Int?,
        pixelRepresentation: Int?,
        photometricInterpretation: String?,
        rescaleSlope: Double?,
        rescaleIntercept: Double?,
        windowCenters: [Double],
        windowWidths: [Double],
        allTags: [String: DICOMTagValue]
    ) {
        self.rows = rows
        self.columns = columns
        self.numberOfSlices = numberOfSlices
        self.pixelSpacing = pixelSpacing
        self.sliceThickness = sliceThickness
        self.spacingBetweenSlices = spacingBetweenSlices
        self.imageOrientationPatient = imageOrientationPatient
        self.imagePositionPatient = imagePositionPatient
        self.frameOfReferenceUID = frameOfReferenceUID
        self.patientName = patientName
        self.patientID = patientID
        self.patientSex = patientSex
        self.patientBirthDate = patientBirthDate
        self.studyInstanceUID = studyInstanceUID
        self.seriesInstanceUID = seriesInstanceUID
        self.studyDescription = studyDescription
        self.seriesDescription = seriesDescription
        self.modality = modality
        self.bitsAllocated = bitsAllocated
        self.bitsStored = bitsStored
        self.highBit = highBit
        self.pixelRepresentation = pixelRepresentation
        self.photometricInterpretation = photometricInterpretation
        self.rescaleSlope = rescaleSlope
        self.rescaleIntercept = rescaleIntercept
        self.windowCenters = windowCenters
        self.windowWidths = windowWidths
        self.allTags = allTags
    }
}
