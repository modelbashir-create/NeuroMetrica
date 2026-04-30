import Foundation
import Combine
import SwiftUI
import simd
import ChromaEngineKit
#if os(macOS)
import AppKit
#endif

/// ViewerViewModel
///
/// Owns all viewer behavior and updates the shared ViewerState.
@MainActor
final class ViewerViewModel: ObservableObject {

    // MARK: - Published properties

    /// Render-ready SwiftUI images by viewport index.
    @Published private(set) var viewportImages: [Int: Image] = [:]

    /// Render-ready SwiftUI images by MPR pane.
    @Published private(set) var mprPaneImages: [MPRPane: Image] = [:]

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
    private var scrollAccumulators: [Int: CGFloat] = [:]
    private var windowLevelDragStates: [Int: WindowLevelDragState] = [:]
    private var panDragStates: [Int: PanDragState] = [:]
    private var crosshairDragStates: [Int: CrosshairDragState] = [:]
    private var viewportGeometries: [Int: ViewportGeometry] = [:]
    private var sliceTasks: [Int: Task<Void, Never>] = [:]
    private var sliceRequestTokens: [Int: Int] = [:]
    private var windowLevelUpdateTask: Task<Void, Never>?
    private var lastWindowLevelUpdateTime: UInt64 = 0
    private let windowLevelThrottleHz: Double = 60.0

    private var mprPaneTasks: [MPRPane: Task<Void, Never>] = [:]
    private var mprPlaneCache: [MPRPane: PatientPlane] = [:]
    private var mprImageCache: [MPRCacheKey: Image] = [:]
    private var mprRefreshTask: Task<Void, Never>?
    private var mprScrollAccumulators: [MPRPane: CGFloat] = [:]
#if DEBUG
    private var mprDebugRequestedPanes: Set<MPRPane> = []
#endif

    private struct MPRCacheKey: Hashable {
        let pane: MPRPane
        let qx: Int
        let qy: Int
        let qz: Int
        let window: Int
        let level: Int
        let interpolation: MPRInterpolation
    }

    private struct WindowLevelDragState {
        let startWindow: Float
        let startLevel: Float
        let startLocation: CGPoint
        var lockedAxis: WindowLevelAxisLock?
    }

    private enum WindowLevelAxisLock {
        case window
        case level
    }

    private struct PanDragState {
        let startPan: CGSize
    }

    private struct CrosshairDragState {
        let isActive: Bool
    }

    private struct ViewportGeometry {
        let viewSize: CGSize
        let contentRect: CGRect
    }

    struct ViewportSliceInfo: Equatable {
        let patientPoint: SIMD3<Double>
        let plane: PatientPlane
        let displayIndex: Int
        let engineIndex: Int
        let sliceCount: Int
    }

    private enum WindowLevelLimits {
        static let minWindow: Float = 1
        static let maxWindow: Float = 4096
        static let minLevel: Float = -1024
        static let maxLevel: Float = 3072
    }

    private let standardWindowLevelPresets: [ViewerWindowLevelPreset] = [
        ViewerWindowLevelPreset(id: "standard-brain", name: "Brain", window: 80, level: 40, source: .standard),
        ViewerWindowLevelPreset(id: "standard-lung", name: "Lung", window: 1500, level: -600, source: .standard),
        ViewerWindowLevelPreset(id: "standard-subdural", name: "Subdural", window: 200, level: 80, source: .standard),
        ViewerWindowLevelPreset(id: "standard-stroke", name: "Stroke", window: 40, level: 40, source: .standard),
        ViewerWindowLevelPreset(id: "standard-bone", name: "Bone", window: 2500, level: 500, source: .standard)
    ]

    private let crosshairHitRadius: CGFloat = 7

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
    }

    // MARK: - UI Shell Actions

    func setLayout(_ mode: LayoutMode) {
        viewerState.setLayout(mode)
        ensureViewportSliceStatesForCurrentLayout()
        refreshViewportSlices()
        stopCineForNonImagingViewports()
    }

    func cycleLayout() {
        viewerState.cycleLayout()
        ensureViewportSliceStatesForCurrentLayout()
        refreshViewportSlices()
        stopCineForNonImagingViewports()
    }

    func setViewerMode(_ mode: ViewerMode) {
        viewerState.viewerMode = mode
    }

    func toggleViewerMode() {
        viewerState.toggleViewerMode()
    }

    func selectTwoDMode() {
        guard viewerState.viewerMode != .twoD else { return }
        viewerState.viewerMode = .twoD
        viewerState.threeDMode = .mpr
        clearMPRState()
        refreshViewportSlices()
    }

    func selectReformatMode(_ mode: ThreeDSubMode) {
        if mode == .mpr {
            guard viewerState.viewerMode != .mpr else { return }
            activateMPRMode()
            refreshMPRSlices()
            return
        }

        if viewerState.viewerMode == .threeD && viewerState.threeDMode == mode {
            return
        }
        viewerState.viewerMode = .threeD
        viewerState.threeDMode = mode
    }

    func enterReformatModeIfNeeded() {
        if viewerState.viewerMode == .twoD {
            activateMPRMode()
            refreshMPRSlices()
        }
    }

    func setThreeDMode(_ mode: ThreeDSubMode) {
        viewerState.threeDMode = mode
    }

    func setActiveTool(_ tool: ViewerTool?) {
        if tool == .fitToView {
            zoomFitActiveView()
            return
        }
        if let tool, tool != .zoom {
            viewerState.lastNonZoomTool = tool
        }
        viewerState.activeTool = tool
    }

    func shouldUseWindowLevelOverride(activeTool: ViewerTool?, optionHeld: Bool) -> Bool {
        guard optionHeld else { return false }
        guard let tool = activeTool, tool != .windowLevel else { return false }
        return true
    }

    func toggleZoomTool() {
        if viewerState.activeTool == .zoom {
            viewerState.activeTool = nil
            viewerState.lastNonZoomTool = nil
            return
        }

        if let activeTool = viewerState.activeTool {
            viewerState.lastNonZoomTool = activeTool
        }
        viewerState.activeTool = .zoom
    }

    func setActiveViewportIndex(_ index: Int) {
        let previous = viewerState.clampedActiveIndex
        viewerState.activeViewportIndex = index
        ensureViewportSliceStateInitialized(for: index)
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

    func resetViewPresentation() {
        guard !viewerState.isLoadingVolume else { return }
        guard let descriptor = currentDescriptor else { return }

        applyDefaultPresentationState(for: descriptor)
        viewerState.lastError = nil
        viewerState.lastErrorContext = nil

        if viewerState.viewerMode == .mpr {
            refreshMPRSlices()
        } else {
            refreshViewportSlices()
        }
    }

    func updateViewportGeometry(for index: Int, viewSize: CGSize, contentRect: CGRect) {
        viewportGeometries[index] = ViewportGeometry(viewSize: viewSize, contentRect: contentRect)
    }

    // MARK: - Volume Loading

    struct ViewerLoadRequest {
        let url: URL
        let context: ViewerErrorContext
        let studyID: String?
        let seriesID: String?
        let studyLabel: String?
        let seriesLabel: String?
        let dicomSelection: DicomImportSelection?
    }

    var canRetryLastLoad: Bool {
        lastLoadRequest != nil
    }

    func openVolume(from url: URL) async {
        await openVolume(from: url, dicomSelection: nil)
    }

    func openVolume(from url: URL, dicomSelection: DicomImportSelection?) async {
        pendingActiveSeries = nil
        let request = ViewerLoadRequest(
            url: url,
            context: .openVolume,
            studyID: url.absoluteString,
            seriesID: nil,
            studyLabel: url.lastPathComponent,
            seriesLabel: nil,
            dicomSelection: dicomSelection
        )
        await loadVolume(request)
    }

    func openVolumes(from urls: [URL]) async {
        for url in urls {
            await openVolume(from: url)
        }
    }

    func openStudy(_ study: Study) async {
        pendingActiveSeries = nil
        let request = ViewerLoadRequest(
            url: study.sourceURL,
            context: .openStudy,
            studyID: study.id,
            seriesID: nil,
            studyLabel: study.title,
            seriesLabel: nil,
            dicomSelection: nil
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
            seriesLabel: seriesLabel,
            dicomSelection: nil
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
        ensureViewportSliceStateInitialized(for: activeIndex)
        updateSlice(for: activeIndex)
    }

    func sliceInfo(for viewportIndex: Int) -> ViewportSliceInfo? {
        guard let descriptor = currentDescriptor else { return nil }
        return makeSliceInfo(for: viewportIndex, descriptor: descriptor)
    }

    func hasSlices(for viewportIndex: Int) -> Bool {
        (sliceInfo(for: viewportIndex)?.sliceCount ?? 0) > 0
    }

    func setSliceIndex(_ index: Int) {
        setSliceIndex(index, for: viewerState.clampedActiveIndex)
    }

    func setSliceIndex(_ index: Int, for viewportIndex: Int) {
        guard !viewerState.isLoadingVolume else { return }
        guard let descriptor = currentDescriptor else { return }
        guard let currentSliceInfo = makeSliceInfo(for: viewportIndex, descriptor: descriptor) else { return }

        let upper = max(currentSliceInfo.sliceCount - 1, 0)
        let clamped = min(max(index, 0), upper)
        guard clamped != currentSliceInfo.displayIndex else { return }

        let updatedPoint = patientPoint(
            for: descriptor,
            orientation: viewerState.orientation(for: viewportIndex),
            displayIndex: clamped,
            referencePoint: currentSliceInfo.patientPoint
        )
        viewerState.setPatientPoint(updatedPoint, for: viewportIndex)
        updateSlice(for: viewportIndex)
    }

    func stepSlice(by delta: Int) {
        stepSlice(by: delta, for: viewerState.clampedActiveIndex)
    }

    func stepSlice(by delta: Int, for viewportIndex: Int) {
        guard !viewerState.isLoadingVolume else { return }
        guard viewerState.isImagingViewport(viewportIndex) else { return }
        guard let sliceInfo = sliceInfo(for: viewportIndex) else { return }

        setSliceIndex(sliceInfo.displayIndex + delta, for: viewportIndex)
    }

    func consumeScrollForSlices(
        deltaY: CGFloat,
        viewportIndex: Int,
        isPrecise: Bool,
        isFast: Bool
    ) -> Int {
        // Values are sourced from Developer Tools settings in AppSettings.
        let baseThreshold = CGFloat(appSettings.sliceScrollBaseThreshold)
        let fastMultiplier = CGFloat(appSettings.sliceScrollFastMultiplier)
        let maxSlicesPerEvent = appSettings.sliceScrollMaxSlicesPerEvent
        let useShiftFastMode = appSettings.sliceScrollUseShiftFastMode

        let clampedBase = min(max(baseThreshold, 20), 80)
        let clampedFast = min(max(fastMultiplier, 2), 6)
        let clampedMax = min(max(maxSlicesPerEvent, 2), 12)

        // Normalize system delta so positive values move forward through slices.
        let normalizedDeltaY = -deltaY

        // Precise trackpad uses a lower threshold for smoother, faster traversal; wheel uses a smaller threshold.
        let coarseThreshold = max(clampedBase / 4, 6)
        let preciseThreshold = max(clampedBase * 0.3, 4)
        let scrollThreshold = isPrecise ? preciseThreshold : coarseThreshold
        let speedScale = min(max(abs(normalizedDeltaY) / max(clampedBase, 1), 0.5), 3)
        let threshold = (scrollThreshold / speedScale) / ((isFast && useShiftFastMode) ? clampedFast : 1)

        var accumulator = (scrollAccumulators[viewportIndex] ?? 0) + normalizedDeltaY
        var steps = 0

        while abs(accumulator) >= threshold && abs(steps) < clampedMax {
            let step = accumulator > 0 ? 1 : -1
            steps += step
            accumulator -= threshold * CGFloat(step)
        }

        scrollAccumulators[viewportIndex] = accumulator
        return steps
    }

    func handleScrollEvent(
        deltaY: CGFloat,
        viewportIndex: Int,
        isPrecise: Bool,
        isFast: Bool,
        phase: NSEvent.Phase,
        momentumPhase: NSEvent.Phase
    ) {
        let momentumScale = CGFloat(min(max(appSettings.sliceScrollMomentumScale, 0.2), 1.0))
        let adjustedDeltaY = momentumPhase.isEmpty ? deltaY : deltaY * momentumScale

        let steps = consumeScrollForSlices(
            deltaY: adjustedDeltaY,
            viewportIndex: viewportIndex,
            isPrecise: isPrecise,
            isFast: isFast
        )
        if steps != 0 {
            stepSlice(by: steps, for: viewportIndex)
        }
    }

    func jumpToFirstSlice() {
        guard !viewerState.isLoadingVolume else { return }
        guard hasSlices(for: viewerState.clampedActiveIndex) else { return }
        setSliceIndex(0, for: viewerState.clampedActiveIndex)
    }

    func jumpToLastSlice() {
        guard !viewerState.isLoadingVolume else { return }
        guard let sliceInfo = sliceInfo(for: viewerState.clampedActiveIndex) else { return }
        setSliceIndex(max(sliceInfo.sliceCount - 1, 0), for: viewerState.clampedActiveIndex)
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
        guard let sliceInfo = sliceInfo(for: viewportIndex), sliceInfo.sliceCount > 1 else { return }
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
        setWindowLevel(window: window, level: viewerState.level)
    }

    func setLevel(_ level: Float) {
        setWindowLevel(window: viewerState.window, level: level)
    }

    func setWindowLevel(window: Float, level: Float) {
        guard !viewerState.isLoadingVolume else { return }
        let resolved = clampWindowLevel(window: window, level: level)
        let clampedWindow = resolved.window
        let clampedLevel = resolved.level
        guard clampedWindow != viewerState.window || clampedLevel != viewerState.level else { return }
        viewerState.window = clampedWindow
        viewerState.level = clampedLevel
        scheduleWindowLevelRefresh()
    }

    func windowLevelPresetSections() -> [ViewerWindowLevelPresetSection] {
        var sections: [ViewerWindowLevelPresetSection] = []
        if !viewerState.dicomWindowLevelPresets.isEmpty {
            sections.append(
                ViewerWindowLevelPresetSection(
                    id: "dicom",
                    title: "DICOM",
                    presets: viewerState.dicomWindowLevelPresets
                )
            )
        }
        sections.append(
            ViewerWindowLevelPresetSection(
                id: "standard",
                title: "Standard",
                presets: standardWindowLevelPresets
            )
        )
        return sections
    }

    func applyWindowLevelPreset(_ preset: ViewerWindowLevelPreset) {
        setWindowLevel(window: preset.window, level: preset.level)
    }

    func beginWindowLevelDrag(at location: CGPoint, viewportIndex: Int) {
        guard !viewerState.isLoadingVolume else { return }
        guard viewerState.isImagingViewport(viewportIndex) else { return }
        if windowLevelDragStates[viewportIndex] != nil { return }
        windowLevelDragStates[viewportIndex] = WindowLevelDragState(
            startWindow: viewerState.window,
            startLevel: viewerState.level,
            startLocation: location
        )
    }

    func updateWindowLevelDrag(
        to location: CGPoint,
        viewportIndex: Int,
        isFineAdjustment: Bool,
        forceAxisLock: Bool
    ) {
        guard !viewerState.isLoadingVolume else { return }
        guard viewerState.isImagingViewport(viewportIndex) else { return }
        if windowLevelDragStates[viewportIndex] == nil {
            beginWindowLevelDrag(at: location, viewportIndex: viewportIndex)
        }
        guard var state = windowLevelDragStates[viewportIndex] else { return }

        let deltaX = Float(location.x - state.startLocation.x)
        let deltaY = Float(location.y - state.startLocation.y)
        let absDeltaX = abs(deltaX)
        let absDeltaY = abs(deltaY)

        if forceAxisLock, state.lockedAxis == nil {
            state.lockedAxis = absDeltaX >= absDeltaY ? .window : .level
            windowLevelDragStates[viewportIndex] = state
        }

        if state.lockedAxis == nil {
            let threshold = Float(appSettings.windowLevelDragAxisLockThreshold)
            if absDeltaX > absDeltaY * (1 + threshold) {
                state.lockedAxis = .window
            } else if absDeltaY > absDeltaX * (1 + threshold) {
                state.lockedAxis = .level
            }
            windowLevelDragStates[viewportIndex] = state
        }

        let levelScale = Float(appSettings.windowLevelDragLevelScale)
        let windowRatio = Float(appSettings.windowLevelDragWindowToLevelRatio)
        let gamma = Float(appSettings.windowLevelDragResponseGamma)
        let deadZone = Float(appSettings.windowLevelDragDeadZonePoints)
        let fineScale = Float(appSettings.windowLevelDragFineAdjustmentScale)
        let levelPerPoint = max(state.startWindow * levelScale, 0.01)
        let windowPerPoint = levelPerPoint * windowRatio

        let sensitivityScale: Float = isFineAdjustment ? fineScale : 1.0
        let adjustedDeltaX = applyDeadZone(deltaX, threshold: deadZone)
        let adjustedDeltaY = applyDeadZone(deltaY, threshold: deadZone)
        let curvedDeltaX = applyResponseCurve(adjustedDeltaX, gamma: gamma) * sensitivityScale
        let curvedDeltaY = applyResponseCurve(adjustedDeltaY, gamma: gamma) * sensitivityScale

        let windowWeight: Float
        let levelWeight: Float

        switch state.lockedAxis {
        case .window:
            windowWeight = 1.0
            levelWeight = 0.2
        case .level:
            windowWeight = 0.2
            levelWeight = 1.0
        case .none:
            windowWeight = 1.0
            levelWeight = 1.0
        }

        let newWindow = state.startWindow + curvedDeltaX * windowPerPoint * windowWeight
        let newLevel = state.startLevel - curvedDeltaY * levelPerPoint * levelWeight
        let snapped = applyPresetSnap(window: newWindow, level: newLevel)
        setWindowLevel(window: snapped.window, level: snapped.level)
    }

    private func applyResponseCurve(_ delta: Float, gamma: Float) -> Float {
        let magnitude = pow(abs(delta), gamma)
        return delta.sign == .minus ? -magnitude : magnitude
    }

    private func applyDeadZone(_ delta: Float, threshold: Float) -> Float {
        let magnitude = abs(delta)
        guard magnitude > threshold else { return 0 }
        let adjusted = magnitude - threshold
        return delta.sign == .minus ? -adjusted : adjusted
    }

    private func scheduleWindowLevelRefresh() {
        guard !windowLevelDragStates.isEmpty else {
            performWindowLevelRefresh()
            return
        }

        let now = DispatchTime.now().uptimeNanoseconds
        let minInterval = UInt64(1_000_000_000 / max(windowLevelThrottleHz, 1))
        let elapsed = now > lastWindowLevelUpdateTime ? (now - lastWindowLevelUpdateTime) : minInterval
        if elapsed >= minInterval {
            lastWindowLevelUpdateTime = now
            performWindowLevelRefresh()
            return
        }

        windowLevelUpdateTask?.cancel()
        let delay = minInterval - elapsed
        windowLevelUpdateTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            guard let self else { return }
            self.lastWindowLevelUpdateTime = DispatchTime.now().uptimeNanoseconds
            self.performWindowLevelRefresh()
        }
    }

    private func performWindowLevelRefresh() {
        if viewerState.viewerMode == .mpr {
            refreshMPRSlices()
            return
        }

        let activeDragIndices = windowLevelDragStates.keys
        if activeDragIndices.isEmpty {
            refreshViewportSlices()
        } else {
            for viewportIndex in activeDragIndices {
                updateSlice(for: viewportIndex)
            }
        }
    }

    private func applyPresetSnap(window: Float, level: Float) -> (window: Float, level: Float) {
        let tolerance = Float(appSettings.windowLevelPresetSnapTolerance)
        let strength = Float(appSettings.windowLevelPresetSnapStrength)
        guard tolerance > 0, strength > 0 else { return (window, level) }

        var bestPreset: ViewerWindowLevelPreset?
        var bestScore: Float = .greatestFiniteMagnitude

        for preset in availableWindowLevelPresets() {
            let windowDelta = abs(window - preset.window) / max(preset.window, 1)
            let levelDelta = abs(level - preset.level) / max(abs(preset.level), 1)
            let maxDelta = max(windowDelta, levelDelta)
            guard maxDelta <= tolerance else { continue }
            if maxDelta < bestScore {
                bestScore = maxDelta
                bestPreset = preset
            }
        }

        guard let preset = bestPreset else { return (window, level) }

        let normalized = min(max(bestScore / max(tolerance, 0.0001), 0), 1)
        let proximity = 1 - normalized
        let blend = min(max(proximity * strength, 0), 1)

        let snappedWindow = window + (preset.window - window) * blend
        let snappedLevel = level + (preset.level - level) * blend
        return (snappedWindow, snappedLevel)
    }

    func endWindowLevelDrag(for viewportIndex: Int) {
        windowLevelDragStates[viewportIndex] = nil
        if windowLevelDragStates.isEmpty {
            windowLevelUpdateTask?.cancel()
            windowLevelUpdateTask = nil
            performWindowLevelRefresh()
        }
    }

    // MARK: - Zoom

    func zoom(for viewportIndex: Int) -> CGFloat {
        viewerState.zoom(for: viewportIndex)
    }

    func setZoom(for viewportIndex: Int, to zoom: CGFloat) {
        guard viewerState.isImagingViewport(viewportIndex) else { return }
        viewerState.setZoom(zoom, for: viewportIndex)
    }

    func stepZoom(for viewportIndex: Int, by factor: CGFloat) {
        guard factor > 0 else { return }
        let currentZoom = viewerState.zoom(for: viewportIndex)
        setZoom(for: viewportIndex, to: currentZoom * factor)
    }

    func pan(for viewportIndex: Int) -> CGSize {
        viewerState.pan(for: viewportIndex)
    }

    func setPan(for viewportIndex: Int, to pan: CGSize) {
        viewerState.setPan(pan, for: viewportIndex)
    }

    func beginPanDrag(for viewportIndex: Int) {
        guard viewerState.isImagingViewport(viewportIndex) else { return }
        if panDragStates[viewportIndex] != nil { return }
        panDragStates[viewportIndex] = PanDragState(startPan: viewerState.pan(for: viewportIndex))
    }

    func updatePanDrag(for viewportIndex: Int, translation: CGSize) {
        guard viewerState.isImagingViewport(viewportIndex) else { return }
        if panDragStates[viewportIndex] == nil {
            beginPanDrag(for: viewportIndex)
        }
        guard let state = panDragStates[viewportIndex] else { return }
        let updated = CGSize(
            width: state.startPan.width + translation.width,
            height: state.startPan.height + translation.height
        )
        setPan(for: viewportIndex, to: updated)
    }

    func endPanDrag(for viewportIndex: Int) {
        panDragStates[viewportIndex] = nil
    }

    // MARK: - Crosshair

    func crosshairViewPoint(
        for viewportIndex: Int,
        viewSize: CGSize,
        contentRect: CGRect,
        aspectRatio: CGFloat?,
        zoom: CGFloat,
        pan: CGSize
    ) -> CGPoint? {
        guard let sliceInfo = sliceInfo(for: viewportIndex) else { return nil }
        let imageSize = CGSize(width: CGFloat(sliceInfo.plane.width), height: CGFloat(sliceInfo.plane.height))
        let imagePoint = imagePoint(for: sliceInfo.patientPoint, on: sliceInfo.plane)
        return imagePointToViewPoint(
            imagePoint,
            viewSize: viewSize,
            imageSize: imageSize,
            aspectRatio: aspectRatio,
            zoom: zoom,
            pan: pan,
            contentRect: contentRect
        )
    }

    func beginCrosshairDrag(
        at viewPoint: CGPoint,
        viewportIndex: Int,
        viewSize: CGSize,
        contentRect: CGRect,
        aspectRatio: CGFloat?,
        zoom: CGFloat,
        pan: CGSize
    ) -> Bool {
        guard viewerState.isImagingViewport(viewportIndex) else { return false }
        guard contentRect.contains(viewPoint) else { return false }
        guard let sliceInfo = sliceInfo(for: viewportIndex) else { return false }
        let imageSize = CGSize(width: CGFloat(sliceInfo.plane.width), height: CGFloat(sliceInfo.plane.height))

        let crosshairViewPoint = imagePointToViewPoint(
            imagePoint(for: sliceInfo.patientPoint, on: sliceInfo.plane),
            viewSize: viewSize,
            imageSize: imageSize,
            aspectRatio: aspectRatio,
            zoom: zoom,
            pan: pan,
            contentRect: contentRect
        )
        guard isPointNearCrosshairLine(
            viewPoint,
            crosshairViewPoint: crosshairViewPoint,
            contentRect: contentRect
        ) else { return false }

        crosshairDragStates[viewportIndex] = CrosshairDragState(isActive: true)
        updateCrosshairDrag(
            to: viewPoint,
            viewportIndex: viewportIndex,
            viewSize: viewSize,
            contentRect: contentRect,
            aspectRatio: aspectRatio,
            zoom: zoom,
            pan: pan
        )
        return true
    }

    func updateCrosshairDrag(
        to viewPoint: CGPoint,
        viewportIndex: Int,
        viewSize: CGSize,
        contentRect: CGRect,
        aspectRatio: CGFloat?,
        zoom: CGFloat,
        pan: CGSize
    ) {
        guard viewerState.isImagingViewport(viewportIndex) else { return }
        guard crosshairDragStates[viewportIndex]?.isActive == true else { return }
        guard let sliceInfo = sliceInfo(for: viewportIndex) else { return }
        let imageSize = CGSize(width: CGFloat(sliceInfo.plane.width), height: CGFloat(sliceInfo.plane.height))

        let imagePoint = viewPointToImagePoint(
            viewPoint,
            viewSize: viewSize,
            imageSize: imageSize,
            aspectRatio: aspectRatio,
            zoom: zoom,
            pan: pan,
            contentRect: contentRect
        )
        let patientPoint = sliceInfo.plane.origin
            + sliceInfo.plane.axisU * (Double(imagePoint.x) * sliceInfo.plane.spacingU)
            + sliceInfo.plane.axisV * (Double(imagePoint.y) * sliceInfo.plane.spacingV)
        viewerState.setPatientPoint(patientPoint, for: viewportIndex)
    }

    func endCrosshairDrag(for viewportIndex: Int) {
        crosshairDragStates[viewportIndex] = nil
    }

    // MARK: - MPR Tri-Planar

    func mprImage(for pane: MPRPane) -> Image? {
        mprPaneImages[pane]
    }

    func mprAspectRatio(for pane: MPRPane) -> CGFloat? {
        guard let plane = mprPlaneCache[pane] else { return nil }
        let width = Double(plane.width) * plane.spacingU
        let height = Double(plane.height) * plane.spacingV
        guard width > 0, height > 0 else { return nil }
        return CGFloat(width / height)
    }

    func mprOverlaySliceDisplay(for pane: MPRPane) -> String {
        let orientation = viewerState.mprOrientationMap[pane] ?? pane.orientation
        let totalSlices = max(mprSliceCount(for: orientation), 1)
        let currentSlice = min(max((mprPlaneCache[pane]?.sliceIndexHint ?? 0) + 1, 1), totalSlices)
        return "\(orientation.rawValue) \(String(format: "%02d", currentSlice))/\(totalSlices)"
    }

    func mprCrosshairViewPoint(
        for pane: MPRPane,
        viewSize: CGSize,
        contentRect: CGRect,
        aspectRatio: CGFloat?
    ) -> CGPoint? {
        guard let plane = mprPlaneCache[pane] else { return nil }
        guard let point = viewerState.mprCrosshairPoint else { return nil }

        let delta = point - plane.origin
        let u = (delta.x * plane.axisU.x + delta.y * plane.axisU.y + delta.z * plane.axisU.z) / plane.spacingU
        let v = (delta.x * plane.axisV.x + delta.y * plane.axisV.y + delta.z * plane.axisV.z) / plane.spacingV
        let imagePoint = CGPoint(x: u, y: v)
        let imageSize = CGSize(width: CGFloat(plane.width), height: CGFloat(plane.height))
        return imagePointToViewPoint(
            imagePoint,
            viewSize: viewSize,
            imageSize: imageSize,
            aspectRatio: aspectRatio,
            zoom: 1.0,
            pan: .zero,
            contentRect: contentRect
        )
    }

    func setMPRCrosshairFromViewPoint(
        _ viewPoint: CGPoint,
        pane: MPRPane,
        viewSize: CGSize,
        contentRect: CGRect,
        aspectRatio: CGFloat?
    ) {
        guard let plane = mprPlaneCache[pane] else { return }
        let imageSize = CGSize(width: CGFloat(plane.width), height: CGFloat(plane.height))
        let imagePoint = viewPointToImagePoint(
            viewPoint,
            viewSize: viewSize,
            imageSize: imageSize,
            aspectRatio: aspectRatio,
            zoom: 1.0,
            pan: .zero,
            contentRect: contentRect
        )
        let patientPoint = plane.origin
            + plane.axisU * (Double(imagePoint.x) * plane.spacingU)
            + plane.axisV * (Double(imagePoint.y) * plane.spacingV)
        setMPRCrosshairPoint(patientPoint)
    }

    func setMPRCrosshairPoint(_ point: SIMD3<Double>) {
        guard let handle = viewerState.volumeHandle else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                let clamped = try await engineBridge.clampPatientPoint(for: handle, point: point)
                await MainActor.run {
                    self.viewerState.mprCrosshairPoint = clamped
                    self.scheduleMPRRefresh()
                }
            } catch {
                await MainActor.run {
                    AppLogger.error("MPR crosshair clamp failed", error: error)
                }
            }
        }
    }

    func stepMPRSlice(by delta: Int, pane: MPRPane) {
        guard delta != 0 else { return }
        guard let descriptor = currentDescriptor else { return }
        guard let currentPoint = viewerState.mprCrosshairPoint else { return }
        let axis = normalAxis(for: pane, descriptor: descriptor)
        let spacing = normalSpacing(for: pane, descriptor: descriptor)
        let newPoint = currentPoint + axis * (Double(delta) * spacing)
        setMPRCrosshairPoint(newPoint)
    }

    func handleMPRScroll(
        deltaY: CGFloat,
        pane: MPRPane,
        isPrecise: Bool,
        isFast: Bool
    ) {
        let steps = consumeMPRScrollSteps(deltaY: deltaY, pane: pane, isPrecise: isPrecise, isFast: isFast)
        guard steps != 0 else { return }
        stepMPRSlice(by: steps, pane: pane)
    }

    func refreshMPRSlices() {
        guard viewerState.viewerMode == .mpr else { return }
        guard viewerState.volumeHandle != nil else {
            mprPaneImages = [:]
            return
        }

#if DEBUG
        mprDebugRequestedPanes = []
#endif
        for pane in MPRPane.allCases {
            updateMPRSlice(for: pane)
        }
    }

    private func clearMPRState() {
        for task in mprPaneTasks.values {
            task.cancel()
        }
        mprPaneTasks = [:]
        mprPaneImages = [:]
        mprPlaneCache = [:]
        mprImageCache = [:]
        mprRefreshTask?.cancel()
        mprRefreshTask = nil
    }

    private func handleRenderingBackendChange() {
        for task in sliceTasks.values {
            task.cancel()
        }
        sliceTasks = [:]
        viewportImages = [:]
        sliceRequestTokens = [:]
        clearMPRState()

        if viewerState.viewerMode == .mpr {
            refreshMPRSlices()
        } else {
            refreshViewportSlices()
        }
    }

    private func scheduleMPRRefresh() {
        mprRefreshTask?.cancel()
        mprRefreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 16_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.refreshMPRSlices()
            }
        }
    }

    private func updateMPRSlice(for pane: MPRPane) {
#if DEBUG
        mprDebugRequestedPanes.insert(pane)
#endif
        mprPaneTasks[pane]?.cancel()
        mprPaneTasks[pane] = nil

        guard let handle = viewerState.volumeHandle else {
            mprPaneImages[pane] = nil
            return
        }
        guard let crosshairPoint = viewerState.mprCrosshairPoint else {
            mprPaneImages[pane] = nil
            return
        }

        let snapshotWindow = viewerState.window
        let snapshotLevel = viewerState.level
        let interpolation = viewerState.mprInterpolation
        let orientation = viewerState.mprOrientationMap[pane] ?? pane.orientation
        let cacheKey = makeMPRCacheKey(pane: pane, point: crosshairPoint)

        let task = Task {
            do {
                let plane = try await engineBridge.makeCanonicalPlane(
                    for: handle,
                    orientation: orientation,
                    crosshairPoint: crosshairPoint
                )

                if let cached = mprImageCache[cacheKey] {
                    await MainActor.run {
                        mprPlaneCache[pane] = plane
                        mprPaneImages[pane] = cached
                    }
                    return
                }

                let slice = try await engineBridge.makeSlice(
                    from: handle,
                    plane: plane,
                    window: snapshotWindow,
                    level: snapshotLevel,
                    interpolation: interpolation
                )
                let cgImage = await Task.detached(priority: .userInitiated) {
                    slice.makeCGImage()
                }.value
                let image = cgImage.map { Image(decorative: $0, scale: 1.0, orientation: .up) }

                await MainActor.run {
                    mprPlaneCache[pane] = plane
                    if let image {
                        mprImageCache[cacheKey] = image
                        mprPaneImages[pane] = image
                    } else {
                        mprPaneImages[pane] = nil
                    }
                }
            } catch {
                await MainActor.run {
                    mprPaneImages[pane] = nil
                    AppLogger.error("MPR slice rendering failed for \(pane)", error: error)
                }
            }
        }

        mprPaneTasks[pane] = task
    }

    private func makeMPRCacheKey(pane: MPRPane, point: SIMD3<Double>) -> MPRCacheKey {
        let quantized = quantizePoint(point, step: 1e-3)
        return MPRCacheKey(
            pane: pane,
            qx: quantized.x,
            qy: quantized.y,
            qz: quantized.z,
            window: Int((viewerState.window * 10).rounded()),
            level: Int((viewerState.level * 10).rounded()),
            interpolation: viewerState.mprInterpolation
        )
    }

    private func quantizePoint(_ point: SIMD3<Double>, step: Double) -> SIMD3<Int> {
        let scale = 1.0 / max(step, 1e-6)
        return SIMD3<Int>(
            Int((point.x * scale).rounded()),
            Int((point.y * scale).rounded()),
            Int((point.z * scale).rounded())
        )
    }

    private func consumeMPRScrollSteps(
        deltaY: CGFloat,
        pane: MPRPane,
        isPrecise: Bool,
        isFast: Bool
    ) -> Int {
        let baseThreshold = CGFloat(appSettings.sliceScrollBaseThreshold)
        let fastMultiplier = CGFloat(appSettings.sliceScrollFastMultiplier)
        let maxSlicesPerEvent = appSettings.sliceScrollMaxSlicesPerEvent
        let useShiftFastMode = appSettings.sliceScrollUseShiftFastMode

        let clampedBase = min(max(baseThreshold, 20), 80)
        let clampedFast = min(max(fastMultiplier, 2), 6)
        let clampedMax = min(max(maxSlicesPerEvent, 2), 12)

        let normalizedDeltaY = -deltaY
        let coarseThreshold = max(clampedBase / 4, 6)
        let preciseThreshold = max(clampedBase * 0.3, 4)
        let scrollThreshold = isPrecise ? preciseThreshold : coarseThreshold
        let speedScale = min(max(abs(normalizedDeltaY) / max(clampedBase, 1), 0.5), 3)
        let threshold = (scrollThreshold / speedScale) / ((isFast && useShiftFastMode) ? clampedFast : 1)

        var accumulator = (mprScrollAccumulators[pane] ?? 0) + normalizedDeltaY
        var steps = 0

        while abs(accumulator) >= threshold && abs(steps) < clampedMax {
            let step = accumulator > 0 ? 1 : -1
            steps += step
            accumulator -= threshold * CGFloat(step)
        }

        mprScrollAccumulators[pane] = accumulator
        return steps
    }

    private func normalAxis(for pane: MPRPane, descriptor: VolumeDescriptor) -> SIMD3<Double> {
        let dir = descriptor.direction
        let axisX = SIMD3<Double>(dir[0], dir[4], dir[8])
        let axisY = SIMD3<Double>(dir[1], dir[5], dir[9])
        let axisZ = SIMD3<Double>(dir[2], dir[6], dir[10])

        switch viewerState.mprOrientationMap[pane] ?? pane.orientation {
        case .axial:
            return axisZ
        case .coronal:
            return axisY
        case .sagittal:
            return axisX
        }
    }

    private func normalSpacing(for pane: MPRPane, descriptor: VolumeDescriptor) -> Double {
        switch viewerState.mprOrientationMap[pane] ?? pane.orientation {
        case .axial:
            return descriptor.spacingZ
        case .coronal:
            return descriptor.spacingY
        case .sagittal:
            return descriptor.spacingX
        }
    }

    private func mprSliceCount(for orientation: SliceOrientation) -> Int {
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

    func zoomFitView(for viewportIndex: Int) {
        let targetZoom = ViewerState.defaultZoom
        let geometry = viewportGeometries[viewportIndex]
        let aspectRatio = displayAspectRatio(for: viewportIndex)
        guard let geometry, let sliceInfo = sliceInfo(for: viewportIndex) else {
            viewerState.resetZoom(for: viewportIndex)
            viewerState.resetPan(for: viewportIndex)
            return
        }
        let imageSize = CGSize(width: CGFloat(sliceInfo.plane.width), height: CGFloat(sliceInfo.plane.height))

        let crosshairPoint = imagePoint(for: sliceInfo.patientPoint, on: sliceInfo.plane)
        let basePoint = imagePointToViewPoint(
            crosshairPoint,
            viewSize: geometry.viewSize,
            imageSize: imageSize,
            aspectRatio: aspectRatio,
            zoom: targetZoom,
            pan: .zero,
            contentRect: geometry.contentRect
        )
        let viewCenter = CGPoint(x: geometry.viewSize.width * 0.5, y: geometry.viewSize.height * 0.5)
        let pan = CGSize(
            width: viewCenter.x - basePoint.x,
            height: viewCenter.y - basePoint.y
        )

        viewerState.setZoom(targetZoom, for: viewportIndex)
        viewerState.setPan(pan, for: viewportIndex)
    }

    func zoomFitActiveView() {
        zoomFitView(for: viewerState.clampedActiveIndex)
    }

    // MARK: - Internal helpers

    private func imagePixelSize(for viewportIndex: Int) -> CGSize? {
        guard let descriptor = currentDescriptor else { return nil }
        let orientation = viewerState.orientation(for: viewportIndex)

        let width: Int
        let height: Int
        switch orientation {
        case .axial:
            width = descriptor.sizeX
            height = descriptor.sizeY
        case .coronal:
            width = descriptor.sizeX
            height = descriptor.sizeZ
        case .sagittal:
            width = descriptor.sizeY
            height = descriptor.sizeZ
        }

        guard width > 0, height > 0 else { return nil }
        return CGSize(width: CGFloat(width), height: CGFloat(height))
    }

    private func imagePointToViewPoint(
        _ imagePoint: CGPoint,
        viewSize: CGSize,
        imageSize: CGSize,
        aspectRatio: CGFloat?,
        zoom: CGFloat,
        pan: CGSize,
        contentRect: CGRect
    ) -> CGPoint {
        let baseRect = fittedImageRect(
            viewSize: viewSize,
            imageSize: imageSize,
            aspectRatio: aspectRatio,
            contentRect: contentRect
        )
        let normalizedX = imageSize.width > 0 ? imagePoint.x / imageSize.width : 0
        let normalizedY = imageSize.height > 0 ? imagePoint.y / imageSize.height : 0
        let basePoint = CGPoint(
            x: baseRect.minX + normalizedX * baseRect.width,
            y: baseRect.minY + normalizedY * baseRect.height
        )

        let viewCenter = CGPoint(x: viewSize.width * 0.5, y: viewSize.height * 0.5)
        let scaled = CGPoint(
            x: viewCenter.x + (basePoint.x - viewCenter.x) * zoom,
            y: viewCenter.y + (basePoint.y - viewCenter.y) * zoom
        )

        return CGPoint(x: scaled.x + pan.width, y: scaled.y + pan.height)
    }

    private func viewPointToImagePoint(
        _ viewPoint: CGPoint,
        viewSize: CGSize,
        imageSize: CGSize,
        aspectRatio: CGFloat?,
        zoom: CGFloat,
        pan: CGSize,
        contentRect: CGRect
    ) -> CGPoint {
        let safeZoom = max(zoom, 0.001)
        let viewCenter = CGPoint(x: viewSize.width * 0.5, y: viewSize.height * 0.5)
        let unpanned = CGPoint(x: viewPoint.x - pan.width, y: viewPoint.y - pan.height)
        let unscaled = CGPoint(
            x: viewCenter.x + (unpanned.x - viewCenter.x) / safeZoom,
            y: viewCenter.y + (unpanned.y - viewCenter.y) / safeZoom
        )

        let baseRect = fittedImageRect(
            viewSize: viewSize,
            imageSize: imageSize,
            aspectRatio: aspectRatio,
            contentRect: contentRect
        )
        let normalizedX = baseRect.width > 0 ? (unscaled.x - baseRect.minX) / baseRect.width : 0
        let normalizedY = baseRect.height > 0 ? (unscaled.y - baseRect.minY) / baseRect.height : 0

        let imageX = min(max(normalizedX, 0), 1) * imageSize.width
        let imageY = min(max(normalizedY, 0), 1) * imageSize.height
        return CGPoint(x: imageX, y: imageY)
    }

    private func fittedImageRect(
        viewSize: CGSize,
        imageSize: CGSize,
        aspectRatio: CGFloat?,
        contentRect: CGRect
    ) -> CGRect {
        let baseAspect = aspectRatio ?? (imageSize.width > 0 ? imageSize.width / imageSize.height : 1)
        guard viewSize.width > 0, viewSize.height > 0, baseAspect > 0 else {
            return contentRect
        }

        let viewAspect = viewSize.width / viewSize.height
        let width: CGFloat
        let height: CGFloat
        if viewAspect > baseAspect {
            height = viewSize.height
            width = height * baseAspect
        } else {
            width = viewSize.width
            height = width / baseAspect
        }

        let origin = CGPoint(
            x: (viewSize.width - width) * 0.5,
            y: (viewSize.height - height) * 0.5
        )
        return CGRect(origin: origin, size: CGSize(width: width, height: height))
    }

    private func isPointNearCrosshairLine(
        _ viewPoint: CGPoint,
        crosshairViewPoint: CGPoint,
        contentRect: CGRect
    ) -> Bool {
        guard contentRect.contains(viewPoint) else { return false }

        let nearVertical = abs(viewPoint.x - crosshairViewPoint.x) <= crosshairHitRadius
            && viewPoint.y >= contentRect.minY
            && viewPoint.y <= contentRect.maxY
        let nearHorizontal = abs(viewPoint.y - crosshairViewPoint.y) <= crosshairHitRadius
            && viewPoint.x >= contentRect.minX
            && viewPoint.x <= contentRect.maxX
        return nearVertical || nearHorizontal
    }

    private func defaultMPRCrosshairPoint(for descriptor: VolumeDescriptor) -> SIMD3<Double> {
        let d = descriptor.direction
        let direction = [
            [d[0], d[1], d[2]],
            [d[4], d[5], d[6]],
            [d[8], d[9], d[10]]
        ]

        let spacing = SIMD3<Double>(descriptor.spacingX, descriptor.spacingY, descriptor.spacingZ)
        let origin = SIMD3<Double>(descriptor.originX, descriptor.originY, descriptor.originZ)
        let centerIndex = SIMD3<Double>(
            Double(max(descriptor.sizeX - 1, 0)) * 0.5,
            Double(max(descriptor.sizeY - 1, 0)) * 0.5,
            Double(max(descriptor.sizeZ - 1, 0)) * 0.5
        )

        let scaled = SIMD3<Double>(
            centerIndex.x * spacing.x,
            centerIndex.y * spacing.y,
            centerIndex.z * spacing.z
        )
        let rotated = SIMD3<Double>(
            direction[0][0] * scaled.x + direction[0][1] * scaled.y + direction[0][2] * scaled.z,
            direction[1][0] * scaled.x + direction[1][1] * scaled.y + direction[1][2] * scaled.z,
            direction[2][0] * scaled.x + direction[2][1] * scaled.y + direction[2][2] * scaled.z
        )

        return origin + rotated
    }

    private func applyDefaultPresentationState(
        for descriptor: VolumeDescriptor,
        reloadWindowLevelBaseline: Bool = false
    ) {
        resetTransientViewerState()
        stopAllCine()
        clearMPRState()
        let centerPoint = defaultMPRCrosshairPoint(for: descriptor)

        for index in 0...LayoutMode.fourUp.maxViewportIndex {
            viewerState.resetZoom(for: index)
            viewerState.resetPan(for: index)
        }

        viewerState.activeViewportIndex = viewerState.clampedActiveIndex
        viewerState.applyDefaultOrientations(for: viewerState.layoutMode)
        viewerState.resetViewportSliceStates()
        if reloadWindowLevelBaseline {
            let resolvedWindowLevelState = resolvedWindowLevelState(for: descriptor.metadata)
            viewerState.baselineWindow = resolvedWindowLevelState.baseline.window
            viewerState.baselineLevel = resolvedWindowLevelState.baseline.level
            viewerState.dicomWindowLevelPresets = resolvedWindowLevelState.dicomPresets
        }
        viewerState.window = viewerState.baselineWindow
        viewerState.level = viewerState.baselineLevel
        ensureViewportSliceStatesForCurrentLayout(preferredPoint: centerPoint)
        viewerState.mprCrosshairPoint = centerPoint
        viewerState.mprActivePane = .axial
        viewerState.mprOrientationMap = ViewerState.defaultMPROrientationMap
    }

    private func resetTransientViewerState() {
        scrollAccumulators = [:]
        windowLevelDragStates = [:]
        panDragStates = [:]
        crosshairDragStates = [:]
        windowLevelUpdateTask?.cancel()
        windowLevelUpdateTask = nil
        lastWindowLevelUpdateTime = 0
        mprScrollAccumulators = [:]
    }

    private func installVolume(_ descriptor: VolumeDescriptor) {
        let shouldPreserveMPR = viewerState.viewerMode == .mpr
        currentDescriptor = descriptor
        viewerState.volumeHandle = descriptor.handle
        viewerState.metadata = descriptor.metadata
        logMetadataDiagnostics()
        viewerState.activeSeries = pendingActiveSeries ?? makeSeries(from: descriptor)
        if let series = viewerState.activeSeries {
            viewerState.currentSeriesLabel = "\(series.seriesDescription) (SER \(series.seriesNumber))"
        }
        let study = makeStudy(from: descriptor)
        if let study {
            viewerState.currentStudyLabel = study.title
        }
        pendingActiveSeries = nil
        applyDefaultPresentationState(for: descriptor, reloadWindowLevelBaseline: true)
        viewerState.viewerMode = shouldPreserveMPR ? .mpr : .twoD
        viewerState.threeDMode = .mpr

        viewerState.isLoadingVolume = false
        viewerState.lastError = nil
        viewerState.lastErrorContext = nil
        viewerState.loadingStudyID = nil
        viewerState.loadingSeriesID = nil
        viewerState.errorStudyID = nil
        viewerState.errorSeriesID = nil
        if viewerState.viewerMode == .mpr {
            refreshMPRSlices()
        } else {
            refreshViewportSlices()
        }

        if let study {
            recentFilesStore.upsertStudy(study)
        }
    }

    private func activateMPRMode() {
        viewerState.viewerMode = .mpr
        viewerState.threeDMode = .mpr
        if viewerState.mprCrosshairPoint == nil, let descriptor = currentDescriptor {
            viewerState.mprCrosshairPoint = defaultMPRCrosshairPoint(for: descriptor)
        }
    }

    private func ensureViewportSliceStatesForCurrentLayout(preferredPoint: SIMD3<Double>? = nil) {
        guard let descriptor = currentDescriptor else { return }
        for index in viewerState.activeViewportIndices where viewerState.isImagingViewport(index) {
            ensureViewportSliceStateInitialized(
                for: index,
                descriptor: descriptor,
                preferredPoint: preferredPoint
            )
        }
    }

    private func ensureViewportSliceStateInitialized(for viewportIndex: Int, preferredPoint: SIMD3<Double>? = nil) {
        guard let descriptor = currentDescriptor else { return }
        _ = ensureViewportSliceStateInitialized(
            for: viewportIndex,
            descriptor: descriptor,
            preferredPoint: preferredPoint
        )
    }

    @discardableResult
    private func ensureViewportSliceStateInitialized(
        for viewportIndex: Int,
        descriptor: VolumeDescriptor,
        preferredPoint: SIMD3<Double>? = nil
    ) -> SIMD3<Double> {
        if let point = viewerState.patientPoint(for: viewportIndex) {
            let clamped = ChromaEngineBridge.clampPatientPoint(descriptor: descriptor, point: point)
            if clamped != point {
                viewerState.setPatientPoint(clamped, for: viewportIndex)
            }
            return clamped
        }

        let seedPoint = preferredPoint ?? defaultMPRCrosshairPoint(for: descriptor)
        let defaultPoint = defaultViewportPatientPoint(
            for: descriptor,
            orientation: viewerState.orientation(for: viewportIndex),
            referencePoint: seedPoint
        )
        viewerState.setPatientPoint(defaultPoint, for: viewportIndex)
        return defaultPoint
    }

    private func defaultViewportPatientPoint(
        for descriptor: VolumeDescriptor,
        orientation: SliceOrientation,
        referencePoint: SIMD3<Double>
    ) -> SIMD3<Double> {
        let count = sliceCount(for: descriptor, orientation: orientation)
        let centeredDisplayIndex = count > 0 ? (count / 2) : 0
        return patientPoint(
            for: descriptor,
            orientation: orientation,
            displayIndex: centeredDisplayIndex,
            referencePoint: referencePoint
        )
    }

    private func makeSliceInfo(
        for viewportIndex: Int,
        descriptor: VolumeDescriptor
    ) -> ViewportSliceInfo? {
        guard viewerState.isImagingViewport(viewportIndex) else { return nil }

        let orientation = viewerState.orientation(for: viewportIndex)
        let count = sliceCount(for: descriptor, orientation: orientation)
        guard count > 0 else { return nil }

        let patientPoint = ensureViewportSliceStateInitialized(for: viewportIndex, descriptor: descriptor)
        let plane = ChromaEngineBridge.makeCanonicalPlane(
            descriptor: descriptor,
            orientation: orientation,
            crosshairPoint: patientPoint
        )
        let engineIndex = min(max(plane.sliceIndexHint, 0), count - 1)
        let displayIndex = max(count - 1, 0) - engineIndex

        return ViewportSliceInfo(
            patientPoint: patientPoint,
            plane: plane,
            displayIndex: displayIndex,
            engineIndex: engineIndex,
            sliceCount: count
        )
    }

    private func refreshViewportSlices() {
        for index in viewerState.activeViewportIndices {
            if viewerState.isImagingViewport(index) {
                updateSlice(for: index)
            } else {
                sliceTasks[index]?.cancel()
                sliceTasks[index] = nil
                viewportImages[index] = nil
            }
        }
    }

    private func updateSlice(for index: Int) {
        sliceTasks[index]?.cancel()
        sliceTasks[index] = nil
        let token = (sliceRequestTokens[index] ?? 0) + 1
        sliceRequestTokens[index] = token

        guard let descriptor = currentDescriptor,
              let sliceInfo = makeSliceInfo(for: index, descriptor: descriptor) else {
            viewportImages[index] = nil
            return
        }

        let snapshotHandle = viewerState.volumeHandle
        let snapshotPlane = sliceInfo.plane
        let snapshotWindow = viewerState.window
        let snapshotLevel = viewerState.level

        let task = Task {
            guard let handle = snapshotHandle else {
                viewportImages[index] = nil
                return
            }

            do {
                guard !Task.isCancelled else { return }
                guard sliceRequestTokens[index] == token else { return }
                let slice = try await engineBridge.makeSlice(
                    from: handle,
                    plane: snapshotPlane,
                    window: snapshotWindow,
                    level: snapshotLevel,
                    interpolation: .linear
                )
                guard !Task.isCancelled else { return }
                guard sliceRequestTokens[index] == token else { return }
                let cgImage = await Task.detached(priority: .userInitiated) {
                    slice.makeCGImage()
                }.value
                guard !Task.isCancelled else { return }
                guard sliceRequestTokens[index] == token else { return }
                let image = cgImage.map { Image(decorative: $0, scale: 1.0, orientation: .up) }
                viewportImages[index] = image
                if viewerState.lastErrorContext == .renderSlice {
                    viewerState.lastError = nil
                    viewerState.lastErrorContext = nil
                }
            } catch {
                guard !Task.isCancelled else { return }
                viewportImages[index] = nil
                let presentation = ViewerErrorPresenter.presentation(for: error, context: .renderSlice)
                viewerState.lastError = presentation
                viewerState.lastErrorContext = presentation.context
                AppLogger.error("Slice rendering failed for viewport \(index)", error: error)
            }
        }
        sliceTasks[index] = task
    }

    private func sliceCount(
        for descriptor: VolumeDescriptor,
        orientation: SliceOrientation
    ) -> Int {
        switch orientation {
        case .axial:
            return descriptor.sizeZ
        case .coronal:
            return descriptor.sizeY
        case .sagittal:
            return descriptor.sizeX
        }
    }

    private func patientPoint(
        for descriptor: VolumeDescriptor,
        orientation: SliceOrientation,
        displayIndex: Int,
        referencePoint: SIMD3<Double>
    ) -> SIMD3<Double> {
        let count = sliceCount(for: descriptor, orientation: orientation)
        guard count > 0 else { return referencePoint }

        let clampedDisplayIndex = min(max(displayIndex, 0), count - 1)
        let engineIndex = max(count - 1, 0) - clampedDisplayIndex
        var voxelIndex = ChromaEngineBridge.patientToVoxelIndex(
            descriptor: descriptor,
            point: referencePoint
        )

        switch orientation {
        case .axial:
            voxelIndex.z = Double(engineIndex)
        case .coronal:
            voxelIndex.y = Double(engineIndex)
        case .sagittal:
            voxelIndex.x = Double(engineIndex)
        }

        let patientPoint = ChromaEngineBridge.voxelToPatient(
            descriptor: descriptor,
            index: voxelIndex
        )
        return ChromaEngineBridge.clampPatientPoint(descriptor: descriptor, point: patientPoint)
    }

    private func imagePoint(for patientPoint: SIMD3<Double>, on plane: PatientPlane) -> CGPoint {
        let delta = patientPoint - plane.origin
        let u = (delta.x * plane.axisU.x + delta.y * plane.axisU.y + delta.z * plane.axisU.z) / plane.spacingU
        let v = (delta.x * plane.axisV.x + delta.y * plane.axisV.y + delta.z * plane.axisV.z) / plane.spacingV

        let maxX = max(CGFloat(plane.width), 0)
        let maxY = max(CGFloat(plane.height), 0)
        return CGPoint(
            x: min(max(CGFloat(u), 0), maxX),
            y: min(max(CGFloat(v), 0), maxY)
        )
    }

    private func stopCineForNonImagingViewports() {
        for index in viewerState.activeViewportIndices where !viewerState.isImagingViewport(index) {
            stopCine(for: index)
        }
    }

    private func stopAllCine() {
        for index in 0...LayoutMode.fourUp.maxViewportIndex {
            stopCine(for: index)
        }
    }


    private func runCineLoop(for viewportIndex: Int) async {
        while !Task.isCancelled {
            let state = viewerState.cineState(for: viewportIndex)
            guard state.isPlaying else { return }
            guard viewerState.isImagingViewport(viewportIndex) else { return }
            guard let sliceInfo = sliceInfo(for: viewportIndex), sliceInfo.sliceCount > 1 else { return }
            guard viewerState.volumeHandle != nil else { return }

            let nextIndex = (sliceInfo.displayIndex + 1) % sliceInfo.sliceCount
            setSliceIndex(nextIndex, for: viewportIndex)

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

        appSettings.$renderingBackendPreference
            .sink { [weak self] preference in
                guard let self else { return }
                Task { @MainActor in
                    await self.engineBridge.updateRenderingBackendPreference(preference)
                    self.handleRenderingBackendChange()
                }
            }
            .store(in: &cancellables)
    }

    private func applyDefaultsFromSettings() {
        let defaults = appDefaultWindowLevel()
        viewerState.baselineWindow = defaults.window
        viewerState.baselineLevel = defaults.level
        viewerState.window = defaults.window
        viewerState.level = defaults.level
    }

    private func clampWindowLevel(window: Float, level: Float) -> (window: Float, level: Float) {
        (
            min(max(window, WindowLevelLimits.minWindow), WindowLevelLimits.maxWindow),
            min(max(level, WindowLevelLimits.minLevel), WindowLevelLimits.maxLevel)
        )
    }

    private func appDefaultWindowLevel() -> (window: Float, level: Float) {
        clampWindowLevel(
            window: Float(appSettings.defaultWindow),
            level: Float(appSettings.defaultLevel)
        )
    }

    private func resolvedWindowLevelState(
        for metadata: CIMetadata
    ) -> (
        baseline: (window: Float, level: Float),
        dicomPresets: [ViewerWindowLevelPreset]
    ) {
        let dicomPresets = dicomWindowLevelPresets(for: metadata)
        let baseline = dicomPresets
            .first
            .map { ($0.window, $0.level) }
            ?? appDefaultWindowLevel()
        return (baseline, dicomPresets)
    }

    private func dicomWindowLevelPresets(for metadata: CIMetadata) -> [ViewerWindowLevelPreset] {
        guard metadata.sourceFormat == .dicom,
              let centers = metadata.windowCenter,
              let widths = metadata.windowWidth,
              !centers.isEmpty,
              centers.count == widths.count else {
            return []
        }

        var presets: [ViewerWindowLevelPreset] = []
        presets.reserveCapacity(widths.count)

        for (index, pair) in zip(centers, widths).enumerated() {
            let center = pair.0
            let width = pair.1
            guard center.isFinite, width.isFinite, width > 0 else { continue }
            let clamped = clampWindowLevel(window: Float(width), level: Float(center))
            let name = widths.count == 1 ? "DICOM" : "DICOM \(index + 1)"
            presets.append(
                ViewerWindowLevelPreset(
                    id: "dicom-\(index)",
                    name: name,
                    window: clamped.window,
                    level: clamped.level,
                    source: .dicom
                )
            )
        }

        return presets
    }

    private func availableWindowLevelPresets() -> [ViewerWindowLevelPreset] {
        viewerState.dicomWindowLevelPresets + standardWindowLevelPresets
    }

    private struct OrientationVector {
        let x: Double
        let y: Double
        let z: Double
    }

    private func normalize(_ vector: OrientationVector) -> OrientationVector? {
        let length = sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
        guard length > 0 else { return nil }
        return OrientationVector(
            x: vector.x / length,
            y: vector.y / length,
            z: vector.z / length
        )
    }

    private func cross(_ a: OrientationVector, _ b: OrientationVector) -> OrientationVector {
        OrientationVector(
            x: a.y * b.z - a.z * b.y,
            y: a.z * b.x - a.x * b.z,
            z: a.x * b.y - a.y * b.x
        )
    }

    private func dominantPatientAxisLabel(for vector: OrientationVector) -> String? {
        let absX = abs(vector.x)
        let absY = abs(vector.y)
        let absZ = abs(vector.z)

        if absX >= absY && absX >= absZ {
            return vector.x >= 0 ? "L" : "R"
        } else if absY >= absX && absY >= absZ {
            return vector.y >= 0 ? "P" : "A"
        } else if absZ >= absX && absZ >= absY {
            return vector.z >= 0 ? "S" : "I"
        }
        return nil
    }

    private func oppositePatientAxisLabel(for label: String) -> String? {
        switch label {
        case "L": return "R"
        case "R": return "L"
        case "A": return "P"
        case "P": return "A"
        case "S": return "I"
        case "I": return "S"
        default: return nil
        }
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

    func orientationLabels(for viewportIndex: Int) -> ViewportOrientationLabels? {
        guard viewerState.isImagingViewport(viewportIndex) else { return nil }
        guard let metadata = viewerState.metadata else { return nil }
        guard let rowValues = metadata.imageOrientationPatientRow,
              let colValues = metadata.imageOrientationPatientColumn,
              let position = metadata.imagePositionPatient,
              rowValues.count == 3,
              colValues.count == 3,
              position.count == 3 else {
            return nil
        }

        guard let row = normalize(OrientationVector(x: rowValues[0], y: rowValues[1], z: rowValues[2])),
              let col = normalize(OrientationVector(x: colValues[0], y: colValues[1], z: colValues[2])) else { return nil }

        guard let normal = normalize(cross(row, col)) else { return nil }

        let xAxis: OrientationVector
        let yAxis: OrientationVector

        switch viewerState.orientation(for: viewportIndex) {
        case .axial:
            xAxis = row
            yAxis = col
        case .coronal:
            xAxis = row
            yAxis = normal
        case .sagittal:
            xAxis = col
            yAxis = normal
        }

        guard let right = dominantPatientAxisLabel(for: xAxis),
              let left = oppositePatientAxisLabel(for: right),
              let bottom = dominantPatientAxisLabel(for: yAxis),
              let top = oppositePatientAxisLabel(for: bottom) else { return nil }

        return ViewportOrientationLabels(left: left, right: right, top: top, bottom: bottom)
    }

    private func logMetadataDiagnostics() {
        guard let metadata = viewerState.metadata else { return }
        let showPHI = appSettings.showDebugOverlay && appSettings.showPHIInDiagnostics
        let report = MetadataDiagnostics.report(for: metadata, showPHI: showPHI)
        MetadataDiagnostics.logReport(report)
    }

    func metadataReport() -> MetadataReport? {
        guard let metadata = viewerState.metadata else { return nil }
        let showPHI = appSettings.showDebugOverlay && appSettings.showPHIInDiagnostics
        return MetadataDiagnostics.report(for: metadata, showPHI: showPHI)
    }

    func imageDataReport() -> ImageDataReport? {
        currentDescriptor?.imageDataReport
    }

#if DEBUG
    func debugRequestedMPRPanes() -> Set<MPRPane> {
        mprDebugRequestedPanes
    }

    func installVolumeForTesting(_ descriptor: VolumeDescriptor) {
        installVolume(descriptor)
    }
#endif

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
            let descriptor = try await engineBridge.loadVolume(
                from: request.url,
                dicomSelection: request.dicomSelection
            )
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
