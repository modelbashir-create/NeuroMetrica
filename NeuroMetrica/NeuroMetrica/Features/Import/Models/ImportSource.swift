import Foundation

/// Describes how an imaging volume (or image stack) entered the app.
///
/// This is intentionally *format-aware* so that the engine bridge can
/// decide how to load it (ITK DICOM, ITK NIfTI, NRRD, PNG stack, etc.).
///
/// IO will be handled by the ITK framework (ITK + DCMTK) underneath.
enum ImportSource: Equatable, Identifiable, Hashable {

    /// A single file volume (e.g. NIfTI, NRRD, MHA, etc.).
    case singleFile(url: URL, format: SingleFileFormat)

    /// A DICOM *series* represented by a directory containing a set of DICOM files.
    /// ITK+DCMTK will be responsible for parsing the series.
    case dicomSeries(directory: URL)

    /// (Optional) Future: explicit PNG/JPEG stack, etc.
    case imageStack(directory: URL)

    // MARK: - Nested Types

    enum SingleFileFormat: String, CaseIterable, Hashable {
        case nifti      // .nii / .nii.gz
        case nrrd       // .nrrd
        case mha        // .mha / .mhd
        case unknown    // fallback if we don’t know yet
    }

    // MARK: - Identifiable

    var id: String {
        switch self {
        case .singleFile(let url, let format):
            return "single:\(format.rawValue):\(url.path)"
        case .dicomSeries(let directory):
            return "dicom:\(directory.path)"
        case .imageStack(let directory):
            return "stack:\(directory.path)"
        }
    }

    // MARK: - Convenience helpers

    /// Quick classification helpers for ImportView / ImportViewModel.
    var isDICOM: Bool {
        if case .dicomSeries = self { return true }
        return false
    }

    var displayName: String {
        switch self {
        case .singleFile(let url, let format):
            return "\(formatDisplayName(format)) – \(url.lastPathComponent)"
        case .dicomSeries(let directory):
            return "DICOM Series – \(directory.lastPathComponent)"
        case .imageStack(let directory):
            return "Image Stack – \(directory.lastPathComponent)"
        }
    }

    private func formatDisplayName(_ format: SingleFileFormat) -> String {
        switch format {
        case .nifti:   return "NIfTI"
        case .nrrd:    return "NRRD"
        case .mha:     return "MHA"
        case .unknown: return "Volume"
        }
    }

    // MARK: - Factory helpers

    /// Factory to construct an `ImportSource` from a picked URL.
    ///
    /// - For **files**: inspects the extension and returns `.singleFile`.
    /// - For **directories**: treats them as a DICOM series by default.
    static func fromPickedURL(_ url: URL) -> ImportSource {
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)

        if isDirectory.boolValue {
            // For now, any picked directory is assumed to be a DICOM series.
            // Later, we could inspect contents for .dcm, etc.
            return .dicomSeries(directory: url)
        } else {
            // Handle multi-part extensions like .nii.gz explicitly
            let lowercasedPath = url.lastPathComponent.lowercased()
            let ext: String

            if lowercasedPath.hasSuffix(".nii.gz") {
                ext = "nii.gz"
            } else {
                ext = url.pathExtension.lowercased()
            }

            let format: SingleFileFormat

            switch ext {
            case "nii", "nii.gz":
                format = .nifti
            case "nrrd":
                format = .nrrd
            case "mha", "mhd":
                format = .mha
            default:
                format = .unknown
            }

            return .singleFile(url: url, format: format)
        }
    }
}
