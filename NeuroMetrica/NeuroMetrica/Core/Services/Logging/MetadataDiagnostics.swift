import Foundation
import ChromaEngineKit

enum MetadataStatus: String {
    case present = "present"
    case missing = "missing"
    case malformed = "malformed"
    case inconsistent = "inconsistent"
    case notApplicable = "n/a"
}

struct MetadataChecklistEntry: Identifiable {
    let id = UUID()
    let label: String
    let tag: String
    let status: MetadataStatus
    let detail: String?
    let isPhi: Bool
    let isOptional: Bool
}

struct MetadataReport {
    let sourceFormat: CIMetadataSourceFormat
    let identity: [MetadataChecklistEntry]
    let geometry: [MetadataChecklistEntry]
    let showPHI: Bool
}

enum MetadataDiagnostics {
    static func report(for metadata: CIMetadata, showPHI: Bool) -> MetadataReport {
        let isDicom = metadata.sourceFormat == .dicom

        let identity: [MetadataChecklistEntry] = [
            entry(label: "Patient Name", tag: "0010,0010", value: metadata.patientName, isDicom: isDicom, isPhi: true, showPHI: showPHI),
            entry(label: "Patient ID", tag: "0010,0020", value: metadata.patientID, isDicom: isDicom, isPhi: true, showPHI: showPHI),
            optionalEntry(label: "Patient Birth Date", tag: "0010,0030", value: metadata.patientBirthDate, isDicom: isDicom, isPhi: true, showPHI: showPHI),
            optionalEntry(label: "Patient Age", tag: "0010,1010", value: metadata.patientAge, isDicom: isDicom, isPhi: true, showPHI: showPHI),
            entry(label: "Patient Sex", tag: "0010,0040", value: metadata.patientSex, isDicom: isDicom, isPhi: true, showPHI: showPHI),
            entry(label: "Study Instance UID", tag: "0020,000D", value: metadata.studyInstanceUID, isDicom: isDicom, isPhi: false, showPHI: showPHI),
            entry(label: "Study Date", tag: "0008,0020", value: metadata.studyDate, isDicom: isDicom, isPhi: false, showPHI: showPHI),
            entry(label: "Study Time", tag: "0008,0030", value: metadata.studyTime, isDicom: isDicom, isPhi: false, showPHI: showPHI),
            entry(label: "Study Description", tag: "0008,1030", value: metadata.studyDescription, isDicom: isDicom, isPhi: false, showPHI: showPHI),
            optionalEntry(label: "Accession Number", tag: "0008,0050", value: metadata.accessionNumber, isDicom: isDicom, isPhi: true, showPHI: showPHI),
            entry(label: "Series Instance UID", tag: "0020,000E", value: metadata.seriesInstanceUID, isDicom: isDicom, isPhi: false, showPHI: showPHI),
            entry(label: "Modality", tag: "0008,0060", value: metadata.modality, isDicom: isDicom, isPhi: false, showPHI: showPHI),
            entry(label: "Series Number", tag: "0020,0011", value: formatInt(metadata.seriesNumber), isDicom: isDicom, isPhi: false, showPHI: showPHI),
            entry(label: "Instance Number", tag: "0020,0013", value: formatInt(metadata.instanceNumber), isDicom: isDicom, isPhi: false, showPHI: showPHI),
            optionalEntry(label: "Manufacturer", tag: "0008,0070", value: metadata.manufacturer, isDicom: isDicom, isPhi: false, showPHI: showPHI),
            optionalEntry(label: "Model Name", tag: "0008,1090", value: metadata.manufacturerModelName, isDicom: isDicom, isPhi: false, showPHI: showPHI)
        ]

        let geometry: [MetadataChecklistEntry] = [
            orientationEntry(metadata: metadata, isDicom: isDicom),
            positionEntry(metadata: metadata, isDicom: isDicom),
            pixelSpacingEntry(metadata: metadata, isDicom: isDicom),
            optionalEntry(label: "Slice Thickness", tag: "0018,0050", value: formatDouble(metadata.sliceThickness), isDicom: isDicom, isPhi: false, showPHI: showPHI),
            optionalEntry(label: "Spacing Between Slices", tag: "0018,0088", value: formatDouble(metadata.spacingBetweenSlices), isDicom: isDicom, isPhi: false, showPHI: showPHI),
            entry(label: "Rows", tag: "0028,0010", value: formatInt(metadata.rows), isDicom: isDicom, isPhi: false, showPHI: showPHI),
            entry(label: "Columns", tag: "0028,0011", value: formatInt(metadata.columns), isDicom: isDicom, isPhi: false, showPHI: showPHI),
            entry(label: "Bits Allocated", tag: "0028,0100", value: formatInt(metadata.bitsAllocated), isDicom: isDicom, isPhi: false, showPHI: showPHI),
            entry(label: "Bits Stored", tag: "0028,0101", value: formatInt(metadata.bitsStored), isDicom: isDicom, isPhi: false, showPHI: showPHI),
            entry(label: "Pixel Representation", tag: "0028,0103", value: formatInt(metadata.pixelRepresentation), isDicom: isDicom, isPhi: false, showPHI: showPHI),
            optionalEntry(label: "Window Center", tag: "0028,1050", value: formatArray(metadata.windowCenter), isDicom: isDicom, isPhi: false, showPHI: showPHI),
            optionalEntry(label: "Window Width", tag: "0028,1051", value: formatArray(metadata.windowWidth), isDicom: isDicom, isPhi: false, showPHI: showPHI)
        ]

        return MetadataReport(
            sourceFormat: metadata.sourceFormat,
            identity: identity,
            geometry: geometry,
            showPHI: showPHI
        )
    }

    static func logReport(_ report: MetadataReport) {
        let entries = report.identity + report.geometry
        let present = entries.filter { $0.status == .present }.count
        let missing = entries.filter { $0.status == .missing }.count
        let malformed = entries.filter { $0.status == .malformed }.count
        let inconsistent = entries.filter { $0.status == .inconsistent }.count
        let notApplicable = entries.filter { $0.status == .notApplicable }.count

        AppLogger.info("Metadata checklist: present=\(present), missing=\(missing), malformed=\(malformed), inconsistent=\(inconsistent), n/a=\(notApplicable)")

        for entry in entries where entry.status == .missing || entry.status == .malformed || entry.status == .inconsistent {
            let phiSuffix = entry.isPhi ? " (PHI)" : ""
            let detail = entry.detail ?? ""
            let message = "Metadata \(entry.status.rawValue): \(entry.label) [\(entry.tag)]\(phiSuffix)\(detail.isEmpty ? "" : " — \(detail)")"
            AppLogger.info(message)
        }
    }

    private static func entry(
        label: String,
        tag: String,
        value: String?,
        isDicom: Bool,
        isPhi: Bool,
        showPHI: Bool
    ) -> MetadataChecklistEntry {
        statusAndDetail(
            label: label,
            tag: tag,
            value: value,
            isDicom: isDicom,
            isPhi: isPhi,
            showPHI: showPHI,
            isOptional: false
        )
    }

    private static func optionalEntry(
        label: String,
        tag: String,
        value: String?,
        isDicom: Bool,
        isPhi: Bool,
        showPHI: Bool
    ) -> MetadataChecklistEntry {
        statusAndDetail(
            label: label,
            tag: tag,
            value: value,
            isDicom: isDicom,
            isPhi: isPhi,
            showPHI: showPHI,
            isOptional: true
        )
    }

    private static func statusAndDetail(
        label: String,
        tag: String,
        value: String?,
        isDicom: Bool,
        isPhi: Bool,
        showPHI: Bool,
        isOptional: Bool
    ) -> MetadataChecklistEntry {
        guard isDicom else {
            return MetadataChecklistEntry(
                label: label,
                tag: tag,
                status: .notApplicable,
                detail: nil,
                isPhi: isPhi,
                isOptional: isOptional
            )
        }

        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasValue = !(trimmed ?? "").isEmpty
        let status: MetadataStatus = hasValue ? .present : .missing
        let detail: String?
        if isPhi && !showPHI {
            detail = hasValue ? "present" : nil
        } else {
            detail = trimmed
        }

        return MetadataChecklistEntry(
            label: label,
            tag: tag,
            status: status,
            detail: detail,
            isPhi: isPhi,
            isOptional: isOptional
        )
    }

    private static func orientationEntry(metadata: CIMetadata, isDicom: Bool) -> MetadataChecklistEntry {
        guard isDicom else {
            return MetadataChecklistEntry(label: "Image Orientation (Patient)", tag: "0020,0037", status: .notApplicable, detail: nil, isPhi: false, isOptional: false)
        }

        let hasTyped = (metadata.imageOrientationPatientRow?.count == 3) && (metadata.imageOrientationPatientColumn?.count == 3)
        let hasTag = metadata.additionalTags["0020,0037"] != nil
        let status: MetadataStatus
        if hasTyped && metadata.imageOrientationConsistentAcrossSlices == false {
            status = .inconsistent
        } else if hasTyped {
            status = .present
        } else if hasTag {
            status = .malformed
        } else {
            status = .missing
        }

        let detail = hasTyped ? "row/col present" : nil
        return MetadataChecklistEntry(
            label: "Image Orientation (Patient)",
            tag: "0020,0037",
            status: status,
            detail: detail,
            isPhi: false,
            isOptional: false
        )
    }

    private static func positionEntry(metadata: CIMetadata, isDicom: Bool) -> MetadataChecklistEntry {
        guard isDicom else {
            return MetadataChecklistEntry(label: "Image Position (Patient)", tag: "0020,0032", status: .notApplicable, detail: nil, isPhi: false, isOptional: false)
        }

        let hasTyped = (metadata.imagePositionPatient?.count == 3)
        let hasTag = metadata.additionalTags["0020,0032"] != nil
        let status: MetadataStatus
        if hasTyped {
            status = .present
        } else if hasTag {
            status = .malformed
        } else {
            status = .missing
        }

        return MetadataChecklistEntry(
            label: "Image Position (Patient)",
            tag: "0020,0032",
            status: status,
            detail: hasTyped ? "present" : nil,
            isPhi: false,
            isOptional: false
        )
    }

    private static func pixelSpacingEntry(metadata: CIMetadata, isDicom: Bool) -> MetadataChecklistEntry {
        guard isDicom else {
            return MetadataChecklistEntry(label: "Pixel Spacing", tag: "0028,0030", status: .notApplicable, detail: nil, isPhi: false, isOptional: false)
        }

        let hasTyped = metadata.pixelSpacing != nil
        let hasTag = metadata.additionalTags["0028,0030"] != nil
        let status: MetadataStatus
        if hasTyped {
            status = .present
        } else if hasTag {
            status = .malformed
        } else {
            status = .missing
        }

        let detail: String?
        if let spacing = metadata.pixelSpacing,
           let row = formatDouble(spacing.row),
           let column = formatDouble(spacing.column) {
            detail = "\(row) × \(column) mm"
        } else {
            detail = nil
        }

        return MetadataChecklistEntry(
            label: "Pixel Spacing",
            tag: "0028,0030",
            status: status,
            detail: detail,
            isPhi: false,
            isOptional: false
        )
    }

    private static func formatInt(_ value: Int?) -> String? {
        guard let value else { return nil }
        return "\(value)"
    }

    private static func formatDouble(_ value: Double?) -> String? {
        guard let value else { return nil }
        return String(format: "%.4f", value)
    }

    private static func formatArray(_ values: [Double]?) -> String? {
        guard let values, !values.isEmpty else { return nil }
        return values.map { String(format: "%.4f", $0) }.joined(separator: " \\ ")
    }
}
