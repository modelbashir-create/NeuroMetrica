import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
final class ImportViewModel: ObservableObject, @unchecked Sendable {
    @Published var searchText: String = ""
    @Published var isFileImporterPresented: Bool = false

    private let filePickerService: FilePickerService
    private let recentFilesStore: RecentFilesStore
    private let volumeRouter: VolumeOpenRouting

    init(
        filePickerService: FilePickerService,
        recentFilesStore: RecentFilesStore,
        volumeRouter: VolumeOpenRouting
    ) {
        self.filePickerService = filePickerService
        self.recentFilesStore = recentFilesStore
        self.volumeRouter = volumeRouter
    }

    var allowedContentTypes: [UTType] {
        FilePickerService.allowedContentTypes
    }

    var studies: [Study] {
        recentFilesStore.studies
    }

    var filteredStudies: [Study] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return studies }

        let needle = trimmed.lowercased()
        return studies.filter { study in
            study.title.lowercased().contains(needle)
                || study.patientName.lowercased().contains(needle)
                || study.modality.lowercased().contains(needle)
                || study.accessionNumber.lowercased().contains(needle)
                || study.id.lowercased().contains(needle)
                || study.series.contains { series in
                    series.seriesDescription.lowercased().contains(needle)
                        || series.seriesNumber.lowercased().contains(needle)
                        || series.modality.lowercased().contains(needle)
                }
        }
    }

    var todayStudies: [Study] {
        filteredStudies.filter { $0.isToday }
    }

    var thisWeekStudies: [Study] {
        filteredStudies.filter { !$0.isToday && $0.isThisWeek }
    }

    var olderStudies: [Study] {
        filteredStudies.filter { !$0.isThisWeek }
    }

    func openImporter() {
        isFileImporterPresented = true
    }

    func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            handleDroppedURLs(urls)
        case .failure(let error):
            AppLogger.error("Import failed", error: error)
        }
    }

    func openStudy(_ study: Study) {
        Task {
            await volumeRouter.openStudy(study)
        }
    }

    func openSeries(_ series: StudySeries, study: Study?) {
        Task {
            await volumeRouter.openSeries(series, study: study)
        }
    }

    // Canvas/sidebar drop handler: routes dropped URLs through the existing import/open flow.
    func handleDroppedURLs(_ urls: [URL]) {
        let targets = filePickerService.loadTargets(from: urls)
        guard !targets.isEmpty else { return }
        Task {
            await volumeRouter.openVolumes(from: targets)
        }
    }

    // Canvas/sidebar drop handler: loads a file URL and routes it through the existing import/open flow.
    func handleDroppedProviders(_ providers: [NSItemProvider]) -> Bool {
        let typeIdentifiers = (FilePickerService.allowedContentTypes + [UTType.fileURL]).map(\.identifier)
        let matchingProviders = providers.compactMap { provider -> (NSItemProvider, String)? in
            guard let typeIdentifier = typeIdentifiers.first(where: { provider.hasItemConformingToTypeIdentifier($0) }) else {
                return nil
            }
            return (provider, typeIdentifier)
        }

        guard !matchingProviders.isEmpty else {
            return false
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            var resolvedURLs: [URL] = []
            for (provider, typeIdentifier) in matchingProviders {
                if let url = await self.loadDroppedURL(from: provider, typeIdentifier: typeIdentifier) {
                    resolvedURLs.append(url)
                }
            }
            self.handleDroppedURLs(resolvedURLs)
        }

        return true
    }

    private func loadDroppedURL(from provider: NSItemProvider, typeIdentifier: String) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { [weak self] url, error in
                guard let self else {
                    continuation.resume(returning: nil)
                    return
                }
                Task { @MainActor in
                    if let error {
                        AppLogger.error("Drop item load failed", error: error)
                        continuation.resume(returning: nil)
                        return
                    }
                    guard let url else {
                        continuation.resume(returning: nil)
                        return
                    }
                    let resolvedURL = self.persistDropFile(from: url) ?? url
                    continuation.resume(returning: resolvedURL)
                }
            }
        }
    }

    // Canvas/sidebar drop handler: copy transient drop URLs into app temp so the loader can access them.
    private func persistDropFile(from url: URL) -> URL? {
        let fileManager = FileManager.default
        let tempRoot = fileManager.temporaryDirectory.appendingPathComponent("NeuroMetricaDrops", isDirectory: true)
        do {
            try fileManager.createDirectory(at: tempRoot, withIntermediateDirectories: true)
            let destination = tempRoot.appendingPathComponent("\(UUID().uuidString)-\(url.lastPathComponent)")
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: url, to: destination)
            return destination
        } catch {
            AppLogger.error("Drop file persistence failed", error: error)
            return nil
        }
    }
}
