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
        guard let url = filePickerService.normalizeSelection(urls) else { return }
        Task {
            await volumeRouter.openVolume(from: url)
        }
    }

    // Canvas/sidebar drop handler: loads a file URL and routes it through the existing import/open flow.
    func handleDroppedProviders(_ providers: [NSItemProvider]) -> Bool {
        let typeIdentifiers = (FilePickerService.allowedContentTypes + [UTType.fileURL]).map(\.identifier)
        guard let provider = providers.first(where: { item in
            typeIdentifiers.contains(where: { item.hasItemConformingToTypeIdentifier($0) })
        }) else {
            return false
        }

        guard let typeIdentifier = typeIdentifiers.first(where: { provider.hasItemConformingToTypeIdentifier($0) }) else {
            return false
        }

        provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { [weak self] url, error in
            guard let self else { return }
            Task { @MainActor in
                if let error {
                    AppLogger.error("Drop item load failed", error: error)
                    return
                }
                guard let url else { return }
                let resolvedURL = self.persistDropFile(from: url) ?? url
                self.handleDroppedURLs([resolvedURL])
            }
        }

        return true
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
