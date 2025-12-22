import Foundation
import UniformTypeIdentifiers

struct FilePickerService {
    static let allowedContentTypes: [UTType] = [
        UTType.folder,
        UTType.data,
        UTType(filenameExtension: "dcm"),
        UTType(filenameExtension: "nii"),
        UTType(filenameExtension: "nrrd"),
        UTType(filenameExtension: "gz")
    ].compactMap { $0 }

    func normalizeSelection(_ urls: [URL]) -> URL? {
        urls.first
    }
}
