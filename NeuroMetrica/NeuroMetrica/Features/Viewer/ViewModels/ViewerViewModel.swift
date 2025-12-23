import Foundation
import Combine
import SwiftUI
import ChromaEngineKit

/// ViewerViewModel
///
/// Owns all viewer behavior and updates the shared ViewerState.
@MainActor
final class ViewerViewModel: ObservableObject {

    // MARK: - Published properties

    /// Render-ready SwiftUI images by viewport index.
    @Published private(set) var viewportImages: [Int: Image] = [:]

    /// Convenience for the active viewport image.
    var currentImage: Image? {
        viewportImages[viewerState.clampedActiveIndex]
    }

    // MARK: - Dependencies

    private let engineBridge: ChromaEngineBridge
    private let viewerState: ViewerState
    private let appSettings: AppSettings
    private let recentFilesStore: RecentFilesStore
    private var cancellables: Set<AnyCancellable> = []

    // MARK: - Internal state

    private var currentDescriptor: VolumeDescriptor?
    private var lastLoadRequest: ViewerLoadRequest?
    private var pendingActiveSeries: StudySeries?
    private var cineTasks: [Int: Task<Void, Never>] = [:]

    // MARK: - Init

    init(
        viewerState: ViewerState,
        engineBridge: ChromaEngineBridge,
        appSettings: AppSettings,
        recentFilesStore: RecentFilesStore
    ) {
        self.viewerState = viewerState
        self.engineBridge = engineBridge
        self.appSettings = appSettings
        self.recentFilesStore = recentFilesStore

        observeSettings()
        applyDefaultsFromSettings()
        Task {
            await engineBridge.updateDicomBackendPreference(appSettings.dicomBackendPreference)
        }
    }

    // MARK: - UI Shell Actions

    func setLayout(_ mode: LayoutMode) {
        viewerState.setLayout(mode)
        updateSliceRange()
        refreshViewportSlices()
        stopCineForNonImagingViewports()
    }

    func cycleLayout() {
        viewerState.cycleLayout()
        updateSliceRange()
        refreshViewportSlices()
        stopCineForNonImagingViewports()
    }

    func setViewerMode(_ mode: ViewerMode) {
        viewerState.viewerMode = mode
    }

    func toggleViewerMode() {
        viewerState.toggleViewerMode()
    }

    func setThreeDMode(_ mode: ThreeDSubMode) {
        viewerState.threeDMode = mode
    }

    func setActiveTool(_ tool: ViewerTool) {
        viewerState.activeTool = tool
    }

    func setActiveViewportIndex(_ index: Int) {
        let previous = viewerState.clampedActiveIndex
        viewerState.activeViewportIndex = index
        updateSliceRange()
        updateSlice(for: index)

        if !viewerState.isImagingViewport(index) {
            stopCine(for: index)
        }
        if previous != index {
            stopCine(for: previous)
        }
    }

    func setExportSheetPresented(_ presented: Bool) {
        viewerState.showExportSheet = presented
    }

    func setSettingsSheetPresented(_ presented: Bool) {
        viewerState.showSettingsSheet = presented
    }

    // MARK: - Volume Loading

    struct ViewerLoadRequest {
        let url: URL
        let context: ViewerErrorContext
        let studyID: String?
        let seriesID: String?
        let studyLabel: String?
        let seriesLabel: String?
    }

    var canRetryLastLoad: Bool {
        lastLoadRequest != nil
    }

    func openVolume(from url: URL) async {
        pendingActiveSeries = nil
        let request = ViewerLoadRequest(
            url: url,
            context: .openVolume,
            studyID: url.absoluteString,
            seriesID: nil,
            studyLabel: url.lastPathComponent,
            seriesLabel: nil
        )
        await loadVolume(request)
    }

    func openStudy(_ study: Study) async {
        pendingActiveSeries = nil
        let request = ViewerLoadRequest(
            url: study.sourceURL,
            context: .openStudy,
            studyID: study.id,
            seriesID: nil,
            studyLabel: study.title,
            seriesLabel: nil
        )
        await loadVolume(request)
    }

    func openSeries(_ series: StudySeries, study: Study?) async {
        pendingActiveSeries = series
        let seriesLabel = "\(series.seriesDescription) (SER \(series.seriesNumber))"
        let request = ViewerLoadRequest(
            url: series.sourceURL,
            context: .openSeries,
            studyID: study?.id ?? series.sourceURL.absoluteString,
            seriesID: series.id,
            studyLabel: study?.title,
            seriesLabel: seriesLabel
        )
        await loadVolume(request)
    }

    func retryLastLoad() async {
        guard let request = lastLoadRequest else { return }
        await loadVolume(request)
    }

    // MARK: - Orientation / Slice / Window Level

    func setOrientation(_ orientation: SliceOrientation) {
        guard !viewerState.isLoadingVolume else { return }
        let activeIndex = viewerState.clampedActiveIndex
        guard orientation != viewerState.orientation(for: activeIndex) else { return }
        viewerState.setOrientation(orientation, for: activeIndex)
        updateSliceRange()
        updateSlice(for: activeIndex)
    }

    func setSliceIndex(_ index: Int) {
        guard !viewerState.isLoadingVolume else { return }
        guard viewerState.sliceCount > 0 else { return }
        let upper = max(viewerState.sliceCount - 1, 0)
        let clamped = min(max(index, 0), upper)
        guard clamped != viewerState.sliceIndex else { return }
        viewerState.sliceIndex = clamped
        refreshViewportSlices()
    }

    func stepSlice(by delta: Int) {
        stepSlice(by: delta, for: viewerState.clampedActiveIndex)
    }

    func stepSlice(by delta: Int, for viewportIndex: Int) {
        guard !viewerState.isLoadingVolume else { return }
        guard viewerState.isImagingViewport(viewportIndex) else { return }
        guard viewerState.sliceCount > 0 else { return }

        setSliceIndex(viewerState.sliceIndex + delta)
    }

    func jumpToFirstSlice() {
        guard !viewerState.isLoadingVolume else { return }
        guard viewerState.sliceCount > 0 else { return }
        setSliceIndex(0)
    }

    func jumpToLastSlice() {
        guard !viewerState.isLoadingVolume else { return }
        guard viewerState.sliceCount > 0 else { return }
        setSliceIndex(max(viewerState.sliceCount - 1, 0))
    }

    func toggleCine(for viewportIndex: Int) {
        guard !viewerState.isLoadingVolume else { return }
        guard viewerState.isImagingViewport(viewportIndex) else { return }
        let isPlaying = viewerState.cineState(for: viewportIndex).isPlaying
        if isPlaying {
            stopCine(for: viewportIndex)
        } else {
            startCine(for: viewportIndex)
        }
    }

    func startCine(for viewportIndex: Int) {
        guard !viewerState.isLoadingVolume else { return }
        guard viewerState.isImagingViewport(viewportIndex) else { return }
        guard viewerState.sliceCount > 1 else { return }
        viewerState.setCinePlaying(true, for: viewportIndex)

        cineTasks[viewportIndex]?.cancel()
        let task = Task { [weak self] in
            guard let self else { return }
            await self.runCineLoop(for: viewportIndex)
        }
        cineTasks[viewportIndex] = task
    }

    func stopCine(for viewportIndex: Int) {
        viewerState.setCinePlaying(false, for: viewportIndex)
        cineTasks[viewportIndex]?.cancel()
        cineTasks[viewportIndex] = nil
    }

    func setCineFPS(_ fps: Double, for viewportIndex: Int) {
        let clamped = min(max(fps, 1), 60)
        viewerState.setCineFPS(clamped, for: viewportIndex)
    }

    func adjustCineFPS(by delta: Double, for viewportIndex: Int) {
        let current = viewerState.cineState(for: viewportIndex).fps
        setCineFPS(current + delta, for: viewportIndex)
    }

    func setWindow(_ window: Float) {
        guard !viewerState.isLoadingVolume else { return }
        guard window != viewerState.window else { return }
        viewerState.window = window
        refreshViewportSlices()
    }

    func setLevel(_ level: Float) {
        guard !viewerState.isLoadingVolume else { return }
        guard level != viewerState.level else { return }
        viewerState.level = level
        refreshViewportSlices()
    }

    // MARK: - Internal helpers

    private func installVolume(_ descriptor: VolumeDescriptor) {
        currentDescriptor = descriptor
        viewerState.volumeHandle = descriptor.handle
        viewerState.metadata = descriptor.metadata
        viewerState.activeSeries = pendingActiveSeries ?? makeSeries(from: descriptor)
        if let series = viewerState.activeSeries {
            viewerState.currentSeriesLabel = "\(series.seriesDescription) (SER \(series.seriesNumber))"
        }
        let study = makeStudy(from: descriptor)
        if let study {
            viewerState.currentStudyLabel = study.title
        }
        pendingActiveSeries = nil
        viewerState.orientation = .axial
        updateSliceRange()

        if viewerState.sliceCount > 0 {
            let middle = viewerState.sliceCount / 2
            viewerState.sliceIndex = min(max(middle, 0), viewerState.sliceCount - 1)
        } else {
            viewerState.sliceIndex = 0
        }

        viewerState.window = Float(appSettings.defaultWindow)
        viewerState.level = Float(appSettings.defaultLevel)

        viewerState.isLoadingVolume = false
        viewerState.lastError = nil
        viewerState.lastErrorContext = nil
        viewerState.loadingStudyID = nil
        viewerState.loadingSeriesID = nil
        viewerState.errorStudyID = nil
        viewerState.errorSeriesID = nil
        refreshViewportSlices()

        if let study {
            recentFilesStore.upsertStudy(study)
        }
    }

    private func updateSliceRange() {
        guard let descriptor = currentDescriptor else {
            viewerState.sliceCount = 0
            viewerState.sliceIndex = 0
            return
        }

        let sliceCount: Int
        switch viewerState.orientation {
        case .axial:
            sliceCount = descriptor.sizeZ
        case .coronal:
            sliceCount = descriptor.sizeY
        case .sagittal:
            sliceCount = descriptor.sizeX
        }

        viewerState.sliceCount = max(sliceCount, 0)

        if viewerState.sliceCount == 0 {
            viewerState.sliceIndex = 0
        } else if viewerState.sliceIndex >= viewerState.sliceCount {
            viewerState.sliceIndex = max(viewerState.sliceCount - 1, 0)
        }
    }

    private func refreshViewportSlices() {
        for index in viewerState.activeViewportIndices {
            if viewerState.isImagingViewport(index) {
                updateSlice(for: index)
            } else {
                viewportImages[index] = nil
            }
        }
    }

    private func updateSlice(for index: Int) {
        let snapshotHandle = viewerState.volumeHandle
        let snapshotOrientation = viewerState.orientation(for: index)
        let snapshotIndex = clampedSliceIndex(for: snapshotOrientation)
        let snapshotWindow = viewerState.window
        let snapshotLevel = viewerState.level

        Task {
            guard let handle = snapshotHandle else {
                viewportImages[index] = nil
                return
            }

            do {
                let slice = try await engineBridge.makeSlice(
                    from: handle,
                    orientation: snapshotOrientation,
                    index: snapshotIndex,
                    window: snapshotWindow,
                    level: snapshotLevel
                )
                let image = slice.toSwiftUIImage()
                viewportImages[index] = image
                if viewerState.lastErrorContext == .renderSlice {
                    viewerState.lastError = nil
                    viewerState.lastErrorContext = nil
                }
            } catch {
                viewportImages[index] = nil
                let presentation = ViewerErrorPresenter.presentation(for: error, context: .renderSlice)
                viewerState.lastError = presentation
                viewerState.lastErrorContext = presentation.context
                AppLogger.error("Slice rendering failed for viewport \(index)", error: error)
            }
        }
    }

    private func clampedSliceIndex(for orientation: SliceOrientation) -> Int {
        let count = sliceCount(for: orientation)
        guard count > 0 else { return 0 }
        return min(max(viewerState.sliceIndex, 0), count - 1)
    }

    private func sliceCount(for orientation: SliceOrientation) -> Int {
        guard let descriptor = currentDescriptor else { return 0 }
        switch orientation {
        case .axial:
            return descriptor.sizeZ
        case .coronal:
            return descriptor.sizeY
        case .sagittal:
            return descriptor.sizeX
        }
    }

    private func stopCineForNonImagingViewports() {
        for index in viewerState.activeViewportIndices where !viewerState.isImagingViewport(index) {
            stopCine(for: index)
        }
    }

    private func stopAllCine() {
        for index in cineTasks.keys {
            stopCine(for: index)
        }
    }

    private func runCineLoop(for viewportIndex: Int) async {
        while !Task.isCancelled {
            let state = viewerState.cineState(for: viewportIndex)
            guard state.isPlaying else { return }
            guard viewerState.isImagingViewport(viewportIndex) else { return }
            guard viewerState.sliceCount > 1 else { return }
            guard viewerState.volumeHandle != nil else { return }

            let count = sliceCount(for: viewerState.orientation(for: viewportIndex))
            guard count > 1 else { return }

            let nextIndex = (viewerState.sliceIndex + 1) % count
            setSliceIndex(nextIndex)

            let delay = UInt64((1.0 / max(state.fps, 1)) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: delay)
        }
    }

    private func observeSettings() {
        appSettings.$dicomBackendPreference
            .sink { [weak self] preference in
                guard let self else { return }
                Task {
                    await self.engineBridge.updateDicomBackendPreference(preference)
                }
            }
            .store(in: &cancellables)
    }

    private func applyDefaultsFromSettings() {
        viewerState.window = Float(appSettings.defaultWindow)
        viewerState.level = Float(appSettings.defaultLevel)
    }

    // MARK: - Viewports

    func image(for index: Int) -> Image? {
        viewportImages[index] ?? nil
    }

    func displayAspectRatio(for viewportIndex: Int) -> CGFloat? {
        guard let descriptor = currentDescriptor else { return nil }

        let width: Double
        let height: Double

        switch viewerState.orientation(for: viewportIndex) {
        case .axial:
            width = Double(descriptor.sizeX) * descriptor.spacingX
            height = Double(descriptor.sizeY) * descriptor.spacingY
        case .coronal:
            width = Double(descriptor.sizeX) * descriptor.spacingX
            height = Double(descriptor.sizeZ) * descriptor.spacingZ
        case .sagittal:
            width = Double(descriptor.sizeY) * descriptor.spacingY
            height = Double(descriptor.sizeZ) * descriptor.spacingZ
        }

        guard width > 0, height > 0 else { return nil }
        return CGFloat(width / height)
    }

    private func loadVolume(_ request: ViewerLoadRequest) async {
        viewerState.isLoadingVolume = true
        viewerState.lastError = nil
        viewerState.lastErrorContext = nil
        viewerState.loadingStudyID = request.studyID ?? request.url.absoluteString
        viewerState.loadingSeriesID = request.seriesID
        viewerState.errorStudyID = nil
        viewerState.errorSeriesID = nil
        viewerState.currentStudyLabel = request.studyLabel
        viewerState.currentSeriesLabel = request.seriesLabel
        lastLoadRequest = request
        stopAllCine()

        let didStartAccess = request.url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                request.url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let descriptor = try await engineBridge.loadVolume(from: request.url)
            installVolume(descriptor)
        } catch {
            viewerState.isLoadingVolume = false
            let presentation = ViewerErrorPresenter.presentation(for: error, context: request.context)
            viewerState.lastError = presentation
            viewerState.lastErrorContext = presentation.context
            viewerState.loadingStudyID = nil
            viewerState.loadingSeriesID = nil
            viewerState.errorStudyID = request.studyID
            viewerState.errorSeriesID = request.seriesID
            AppLogger.error("Volume load failed for \(request.url.path)", error: error)
        }
    }

    private func makeStudy(from descriptor: VolumeDescriptor) -> Study? {
        let metadata = descriptor.metadata
        let title = metadata.seriesDescription ?? metadata.studyDescription ?? descriptor.url.lastPathComponent
        let modality = metadata.modality ?? "—"
        let patientName = metadata.patientName ?? "UNKNOWN"
        let accession = metadata.accessionNumber ?? metadata.studyID ?? descriptor.handle.id.uuidString

        let date = parseDate(metadata.acquisitionDate) ?? .now
        let seriesCount = Int(metadata.additionalTags["0020,1209"] ?? "") ?? 1
        let series = [makeSeries(from: descriptor)].compactMap { $0 }
        let id = descriptor.url.absoluteString

        return Study(
            id: id,
            title: title,
            modality: modality,
            date: date,
            patientName: patientName,
            accessionNumber: accession,
            seriesCount: max(seriesCount, 1),
            sourceURL: descriptor.url,
            series: series
        )
    }

    private func makeSeries(from descriptor: VolumeDescriptor) -> StudySeries? {
        let metadata = descriptor.metadata
        let description = metadata.seriesDescription ?? "Series"
        let seriesNumber = metadata.additionalTags["0020,0011"] ?? "—"
        let modality = metadata.modality ?? "—"
        let imagesCount = max(descriptor.sizeZ, 0)
        let id = metadata.seriesInstanceUID ?? descriptor.url.absoluteString

        return StudySeries(
            id: id,
            seriesDescription: description,
            seriesNumber: seriesNumber,
            modality: modality,
            imagesCount: imagesCount,
            sourceURL: descriptor.url
        )
    }

    private func parseDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: trimmed)
    }

}

extension ViewerViewModel: VolumeOpenRouting {}
