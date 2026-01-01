import Foundation
import Combine
import SwiftUI
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

    private struct WindowLevelPreset {
        let name: String
        let window: Float
        let level: Float
    }

    private enum WindowLevelLimits {
        static let minWindow: Float = 1
        static let maxWindow: Float = 4096
        static let minLevel: Float = -1024
        static let maxLevel: Float = 3072
    }

    private let windowLevelPresets: [WindowLevelPreset] = [
        WindowLevelPreset(name: "Brain", window: 80, level: 40),
        WindowLevelPreset(name: "Lung", window: 1500, level: -600),
        WindowLevelPreset(name: "Bone", window: 2500, level: 500)
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

    func selectTwoDMode() {
        guard viewerState.viewerMode != .twoD else { return }
        viewerState.viewerMode = .twoD
        viewerState.threeDMode = .mpr
    }

    func selectReformatMode(_ mode: ThreeDSubMode) {
        if viewerState.viewerMode == .threeD && viewerState.threeDMode == mode {
            return
        }
        viewerState.viewerMode = .threeD
        viewerState.threeDMode = mode
    }

    func enterReformatModeIfNeeded() {
        if viewerState.viewerMode == .twoD {
            viewerState.viewerMode = .threeD
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
        setWindowLevel(window: window, level: viewerState.level)
    }

    func setLevel(_ level: Float) {
        setWindowLevel(window: viewerState.window, level: level)
    }

    func setWindowLevel(window: Float, level: Float) {
        guard !viewerState.isLoadingVolume else { return }
        let clampedWindow = min(max(window, WindowLevelLimits.minWindow), WindowLevelLimits.maxWindow)
        let clampedLevel = min(max(level, WindowLevelLimits.minLevel), WindowLevelLimits.maxLevel)
        guard clampedWindow != viewerState.window || clampedLevel != viewerState.level else { return }
        viewerState.window = clampedWindow
        viewerState.level = clampedLevel
        scheduleWindowLevelRefresh()
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

        var bestPreset: WindowLevelPreset?
        var bestScore: Float = .greatestFiniteMagnitude

        for preset in windowLevelPresets {
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
        guard let imageSize = imagePixelSize(for: viewportIndex) else { return nil }
        let imagePoint = viewerState.crosshairPoint(for: viewportIndex, imageSize: imageSize)
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
        guard let imageSize = imagePixelSize(for: viewportIndex) else { return false }

        let crosshairViewPoint = imagePointToViewPoint(
            viewerState.crosshairPoint(for: viewportIndex, imageSize: imageSize),
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
        guard let imageSize = imagePixelSize(for: viewportIndex) else { return }

        let imagePoint = viewPointToImagePoint(
            viewPoint,
            viewSize: viewSize,
            imageSize: imageSize,
            aspectRatio: aspectRatio,
            zoom: zoom,
            pan: pan,
            contentRect: contentRect
        )
        viewerState.setCrosshairPoint(imagePoint, for: viewportIndex, imageSize: imageSize)
    }

    func endCrosshairDrag(for viewportIndex: Int) {
        crosshairDragStates[viewportIndex] = nil
    }

    func zoomFitView(for viewportIndex: Int) {
        let targetZoom = ViewerState.defaultZoom
        let geometry = viewportGeometries[viewportIndex]
        let aspectRatio = displayAspectRatio(for: viewportIndex)
        guard let geometry, let imageSize = imagePixelSize(for: viewportIndex) else {
            viewerState.resetZoom(for: viewportIndex)
            viewerState.resetPan(for: viewportIndex)
            return
        }

        let crosshairPoint = viewerState.crosshairPoint(for: viewportIndex, imageSize: imageSize)
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

    private func installVolume(_ descriptor: VolumeDescriptor) {
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
        viewerState.resetCrosshairPoints()
        viewerState.viewerMode = .twoD
        viewerState.threeDMode = .mpr

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

        let snapshotHandle = viewerState.volumeHandle
        let snapshotOrientation = viewerState.orientation(for: index)
        let snapshotIndex = engineSliceIndex(for: snapshotOrientation)
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
                    orientation: snapshotOrientation,
                    index: snapshotIndex,
                    window: snapshotWindow,
                    level: snapshotLevel
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

    private func engineSliceIndex(for orientation: SliceOrientation) -> Int {
        let count = sliceCount(for: orientation)
        guard count > 0 else { return 0 }
        let clamped = min(max(viewerState.sliceIndex, 0), count - 1)
        return max(count - 1, 0) - clamped
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
