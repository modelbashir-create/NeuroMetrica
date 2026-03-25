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

    func loadTargets(from urls: [URL]) -> [URL] {
        let normalized = normalizeSelections(urls)
        guard !normalized.isEmpty else { return [] }

        let dicomParents = Dictionary(grouping: normalized.filter(isDicomFile), by: { $0.deletingLastPathComponent().standardizedFileURL.path })
        var targets: [URL] = []
        var seenPaths: Set<String> = []

        for url in normalized {
            let target: URL
            if isDicomFile(url),
               let parentGroup = dicomParents[url.deletingLastPathComponent().standardizedFileURL.path],
               parentGroup.count > 1 {
                target = url.deletingLastPathComponent().standardizedFileURL
            } else {
                target = url
            }

            let path = target.standardizedFileURL.path
            if seenPaths.insert(path).inserted {
                targets.append(target)
            }
        }

        return targets
    }

    private func normalizeSelections(_ urls: [URL]) -> [URL] {
        var result: [URL] = []
        var seenPaths: Set<String> = []

        for url in urls {
            let normalized = url.standardizedFileURL
            if seenPaths.insert(normalized.path).inserted {
                result.append(normalized)
            }
        }

        return result
    }

    private func isDicomFile(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "dcm"
    }
}
