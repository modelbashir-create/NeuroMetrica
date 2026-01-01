//
//  CISliceProvenance.swift
//  ChromaEngineKit
//
//  Per-slice DICOM provenance captured at load time.
//

import Foundation

/// Per-slice provenance captured directly from DICOM metadata.
///
/// This data preserves the raw order returned by the DICOM reader and is
/// intended for validation/audit rather than UI display.
public struct CISliceProvenance: Sendable, Equatable {
    public var instanceUID: String?
    public var instanceNumber: Int?
    public var imagePositionPatient: [Double]?
    public var imageOrientationPatient: [Double]?

    public init(
        instanceUID: String? = nil,
        instanceNumber: Int? = nil,
        imagePositionPatient: [Double]? = nil,
        imageOrientationPatient: [Double]? = nil
    ) {
        self.instanceUID = instanceUID
        self.instanceNumber = instanceNumber
        self.imagePositionPatient = imagePositionPatient
        self.imageOrientationPatient = imageOrientationPatient
    }
}
