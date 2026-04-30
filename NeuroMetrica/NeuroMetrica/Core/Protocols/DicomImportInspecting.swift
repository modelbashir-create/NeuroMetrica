import Foundation

protocol DicomImportInspecting {
    func inspectImport(at url: URL) async throws -> DicomImportInspection?
}
