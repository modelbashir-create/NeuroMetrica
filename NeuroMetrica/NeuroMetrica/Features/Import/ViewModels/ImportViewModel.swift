import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
final class ImportViewModel: ObservableObject, @unchecked Sendable {
    @Published var searchText: String = ""
    @Published var isFileImporterPresented: Bool = false
    @Published private(set) var pendingDicomReviewSession: DicomImportReviewSession?

    private let filePickerService: FilePickerService
    private let recentFilesStore: RecentFilesStore
    private let volumeRouter: VolumeOpenRouting
    private let dicomImportInspector: DicomImportInspecting
    private var queuedImportTargets: [URL] = []
    private var isProcessingQueuedImports: Bool = false

    init(
        filePickerService: FilePickerService,
        recentFilesStore: RecentFilesStore,
        volumeRouter: VolumeOpenRouting,
        dicomImportInspector: DicomImportInspecting
    ) {
        self.filePickerService = filePickerService
        self.recentFilesStore = recentFilesStore
        self.volumeRouter = volumeRouter
        self.dicomImportInspector = dicomImportInspector
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
            await processImportTargets(targets)
        }
    }

    func selectPendingDicomReviewOption(id: String) {
        guard var session = pendingDicomReviewSession else { return }
        guard session.options.contains(where: { $0.id == id }) else { return }
        session.selectedOptionID = id
        pendingDicomReviewSession = session
    }

    func confirmPendingDicomReview() {
        guard let session = pendingDicomReviewSession else { return }
        pendingDicomReviewSession = nil

        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.volumeRouter.openVolume(
                from: session.sourceURL,
                dicomSelection: session.selectedOption?.selection
            )
            await self.processQueuedImportsIfNeeded()
        }
    }

    func dismissPendingDicomReview() {
        pendingDicomReviewSession = nil

        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.processQueuedImportsIfNeeded()
        }
    }

    func processImportTargets(_ targets: [URL]) async {
        guard !targets.isEmpty else { return }
        queuedImportTargets.append(contentsOf: targets)
        await processQueuedImportsIfNeeded()
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

    private func processQueuedImportsIfNeeded() async {
        guard !isProcessingQueuedImports else { return }
        guard pendingDicomReviewSession == nil else { return }

        isProcessingQueuedImports = true
        defer { isProcessingQueuedImports = false }

        while pendingDicomReviewSession == nil, !queuedImportTargets.isEmpty {
            let url = queuedImportTargets.removeFirst()
            await processImportTarget(url)
        }
    }

    private func processImportTarget(_ url: URL) async {
        let inspection = await inspectDicomImportIfNeeded(at: url)
        if let inspection, inspection.shouldPresentReview {
            pendingDicomReviewSession = DicomImportReviewSession(
                sourceURL: url,
                inspection: inspection
            )
            return
        }

        await volumeRouter.openVolume(
            from: url,
            dicomSelection: inspection?.recommendedSelection
        )
    }

    private func inspectDicomImportIfNeeded(at url: URL) async -> DicomImportInspection? {
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            return try await dicomImportInspector.inspectImport(at: url)
        } catch {
            AppLogger.error("DICOM import inspection failed for \(url.path)", error: error)
            return nil
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
