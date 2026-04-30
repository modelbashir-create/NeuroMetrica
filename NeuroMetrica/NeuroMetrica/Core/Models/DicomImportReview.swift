import Foundation

struct DicomImportSelection: Sendable, Equatable {
    let seriesInstanceUID: String
    let subseriesKey: String?
}

struct DicomImportOption: Identifiable, Sendable, Equatable {
    let selection: DicomImportSelection
    let studyDescription: String?
    let seriesDescription: String?
    let modality: String?
    let seriesNumber: String?
    let fileCount: Int
    let confidence: Int
    let orientationConsistent: Bool?
    let spacingUniform: Bool?
    let spacingReferenceMm: Double?
    let maxSpacingErrorMm: Double?
    let reasons: [String]
    let isRecommended: Bool

    nonisolated var id: String {
        if let subseriesKey = selection.subseriesKey {
            return "\(selection.seriesInstanceUID)|\(subseriesKey)"
        }
        return selection.seriesInstanceUID
    }

    nonisolated var title: String {
        if let seriesDescription, !seriesDescription.isEmpty {
            return seriesDescription
        }
        if let studyDescription, !studyDescription.isEmpty {
            return studyDescription
        }
        return "DICOM Series"
    }

    nonisolated var subtitle: String {
        var parts: [String] = []
        if let modality, !modality.isEmpty {
            parts.append(modality)
        }
        if let seriesNumber, !seriesNumber.isEmpty {
            parts.append("SER \(seriesNumber)")
        }
        parts.append("\(fileCount) images")
        return parts.joined(separator: " | ")
    }

    nonisolated var requiresAttention: Bool {
        hasGeometryWarning || !displayReasons.isEmpty
    }

    nonisolated var hasGeometryWarning: Bool {
        orientationConsistent == false || spacingUniform == false
    }

    nonisolated var displayReasons: [String] {
        reasons.map(Self.localizedReason)
    }

    nonisolated private static func localizedReason(_ reason: String) -> String {
        switch reason {
        case "missingPixelData":
            return "Missing pixel data"
        case "singleSlice":
            return "Single-slice acquisition"
        case "orientationInconsistent":
            return "Inconsistent slice orientation"
        case "spacingNonUniform":
            return "Non-uniform slice spacing"
        case "localizerLike":
            return "Localizer-like acquisition"
        default:
            return reason
        }
    }
}

struct DicomImportInspection: Sendable, Equatable {
    let options: [DicomImportOption]
    let recommendedSelection: DicomImportSelection?
    let selectionPolicy: String?

    var recommendedOptionID: String? {
        guard let recommendedSelection else { return nil }
        if let subseriesKey = recommendedSelection.subseriesKey {
            return "\(recommendedSelection.seriesInstanceUID)|\(subseriesKey)"
        }
        return recommendedSelection.seriesInstanceUID
    }

    var recommendedOption: DicomImportOption? {
        guard let recommendedOptionID else { return options.first }
        return options.first { $0.id == recommendedOptionID } ?? options.first
    }

    var isAmbiguous: Bool {
        options.count > 1
    }

    var shouldPresentReview: Bool {
        isAmbiguous || (recommendedOption?.requiresAttention ?? false)
    }
}

struct DicomImportReviewSession: Identifiable, Equatable {
    let id: UUID
    let sourceURL: URL
    let inspection: DicomImportInspection
    var selectedOptionID: String

    init(
        id: UUID = UUID(),
        sourceURL: URL,
        inspection: DicomImportInspection
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.inspection = inspection
        self.selectedOptionID = inspection.recommendedOptionID ?? inspection.options.first?.id ?? ""
    }

    var options: [DicomImportOption] {
        inspection.options
    }

    var selectedOption: DicomImportOption? {
        options.first { $0.id == selectedOptionID } ?? options.first
    }
}
