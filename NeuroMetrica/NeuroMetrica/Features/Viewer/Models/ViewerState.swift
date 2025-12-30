import Foundation
import SwiftUI
import Observation
import ChromaEngineKit   // for VolumeHandle + SliceOrientation

// MARK: - Layout & Viewer Enums

/// Layout of the viewer canvas (1-up / 2-up / 3-up / 4-up)
enum LayoutMode: String, CaseIterable, Identifiable {
    case oneUp   = "1-up"
    case twoUp   = "2-up"
    case threeUp = "3-up"
    case fourUp  = "4-up"

    var id: String { rawValue }

    /// Next layout in the cycle
    var next: LayoutMode {
        switch self {
        case .oneUp:   return .twoUp
        case .twoUp:   return .threeUp
        case .threeUp: return .fourUp
        case .fourUp:  return .oneUp
        }
    }

    /// Maximum viewport index for this layout
    var maxViewportIndex: Int {
        switch self {
        case .oneUp:   return 0
        case .twoUp:   return 1
        case .threeUp: return 2
        case .fourUp:  return 3
        }
    }
}

/// 2D vs 3D viewer mode
enum ViewerMode: String, CaseIterable, Identifiable {
    case twoD   = "2D"
    case threeD = "3D"

    var id: String { rawValue }
}

/// Sub-modes for 3D viewing
enum ThreeDSubMode: String, CaseIterable, Identifiable {
    case mpr = "MPR"
    case vr  = "VR"
    case mip = "MIP"

    var id: String { rawValue }
}

/// Active tool in the viewer toolbar
enum ViewerTool: String, CaseIterable, Identifiable {
    case windowLevel = "Window/Level"
    case pan         = "Pan"
    case fitToView   = "Fit to View"
    case zoom        = "Zoom"
    case measure     = "Measure"
    case cine        = "Cine"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .windowLevel: return "circle.lefthalf.filled"
        case .pan:         return "hand.raised"
        case .fitToView:   return "arrow.up.backward.and.arrow.down.forward.rectangle"
        case .zoom:        return "magnifyingglass.circle"
        case .measure:     return "ruler"
        case .cine:        return "play"
        }
    }

    static var allCases: [ViewerTool] {
        [.windowLevel, .zoom, .pan, .fitToView, .cine, .measure]
    }
}


// MARK: - Observable Viewer State (UI + Imaging)

/// Canonical viewer state used by the mockup UI and the ViewerViewModel.
///
/// - UI/layout: layoutMode, viewerMode, threeDMode, active viewport, active tool, sheets
/// - Imaging: volume handle, orientation, slice index/count, WW/WL, loading/error flags
@Observable
@MainActor
final class ViewerState {

    // MARK: UI / Layout State

    /// Current layout mode (1-up / 2-up / 3-up / 4-up)
    var layoutMode: LayoutMode = .oneUp

    /// 2D vs 3D mode
    var viewerMode: ViewerMode = .twoD

    /// 3D sub-mode (only used when viewerMode == .threeD)
    var threeDMode: ThreeDSubMode = .mpr

    /// Active viewport index (0...layoutMode.maxViewportIndex)
    var activeViewportIndex: Int = 0

    /// Currently selected tool in the viewer toolbar
    var activeTool: ViewerTool? = nil

    /// Last non-zoom tool, used to restore the previous mode when toggling Zoom off.
    var lastNonZoomTool: ViewerTool? = nil

    // Sheet presentation states
    var showExportSheet: Bool = false
    var showSettingsSheet: Bool = false

    /// Active viewport index, clamped into the valid range for the current layout
    var clampedActiveIndex: Int {
        min(max(activeViewportIndex, 0), layoutMode.maxViewportIndex)
    }

    /// Cycle to the next layout mode
    func cycleLayout() {
        layoutMode = layoutMode.next
        if activeViewportIndex > layoutMode.maxViewportIndex {
            activeViewportIndex = 0
        }
        applyDefaultOrientations(for: layoutMode)
    }

    /// Toggle between 2D and 3D modes
    func toggleViewerMode() {
        viewerMode = (viewerMode == .twoD) ? .threeD : .twoD
    }

    /// Explicitly set the layout mode
    func setLayout(_ mode: LayoutMode) {
        layoutMode = mode
        if activeViewportIndex > layoutMode.maxViewportIndex {
            activeViewportIndex = 0
        }
        applyDefaultOrientations(for: layoutMode)
    }


    // MARK: Imaging State (Volume / Slices / WWL)

    /// Handle returned by ChromaEngine after loading a volume
    var volumeHandle: VolumeHandle? = nil

    /// Canonical metadata for the loaded volume.
    var metadata: CIMetadata? = nil

    /// Active series metadata from the Study browser.
    var activeSeries: StudySeries? = nil

    /// Internal tracked index for orientation:
    /// Stored per-viewport orientations keyed by viewport index.
    private var viewportOrientations: [Int: SliceOrientation] = [:]

    /// Orientation for the currently active viewport.
    var orientation: SliceOrientation {
        get { orientation(for: clampedActiveIndex) }
        set { setOrientation(newValue, for: clampedActiveIndex) }
    }

    /// Zero-based slice index within the current orientation
    var sliceIndex: Int = 0

    /// Total number of slices available in the current orientation
    var sliceCount: Int = 0

    /// Window width and level (engine-space)
    var window: Float = 350
    var level: Float = 40

    // MARK: Zoom state

    static let defaultZoom: CGFloat = 1.0
    static let minZoom: CGFloat = 0.5
    static let maxZoom: CGFloat = 5.0
    static let defaultPan: CGSize = .zero

    private var viewportZooms: [Int: CGFloat] = [:]
    private var viewportPans: [Int: CGSize] = [:]
    private var viewportCrosshairPoints: [Int: CGPoint] = [:]

    /// Indicates an async load / reslice is in progress
    var isLoadingVolume: Bool = false

    /// Last user-visible error message, if any
    var lastError: ViewerErrorPresentation? = nil
    var lastErrorContext: ViewerErrorContext? = nil

    /// Current loading labels for PACS-style overlays
    var currentStudyLabel: String? = nil
    var currentSeriesLabel: String? = nil

    /// Loading/error context for sidebar indicators
    var loadingStudyID: String? = nil
    var loadingSeriesID: String? = nil
    var errorStudyID: String? = nil
    var errorSeriesID: String? = nil

    // MARK: Cine state

    struct ViewportCineState: Equatable {
        var isPlaying: Bool
        var fps: Double
    }

    private var cineStates: [Int: ViewportCineState] = [:]

    /// Whether a volume is currently loaded
    var hasVolume: Bool {
        volumeHandle != nil
    }

    /// Slice index clamped into [0, sliceCount - 1]
    var clampedSliceIndex: Int {
        guard sliceCount > 0 else { return 0 }
        return max(0, min(sliceIndex, sliceCount - 1))
    }

    // MARK: - Overlay display helpers

    var seriesTitle: String {
        if let series = activeSeries, !series.seriesDescription.isEmpty {
            return series.seriesDescription
        }
        if let description = metadata?.seriesDescription, !description.isEmpty {
            return description
        }
        if let study = metadata?.studyDescription, !study.isEmpty {
            return study
        }
        return metadata?.modality ?? "Series"
    }

    var seriesSubtitle: String {
        if let series = activeSeries {
            return "SER \(series.seriesNumber)  \(series.modality)"
        }
        let modality = metadata?.modality ?? "—"
        let seriesNumber = metadata?.additionalTags["0020,0011"] ?? "—"
        return "SER \(seriesNumber)  \(modality)"
    }

    var seriesImagesDisplay: String {
        if let series = activeSeries {
            return "\(series.imagesCount)"
        }
        if let total = metadata?.additionalTags["0020,1209"], !total.isEmpty {
            return total
        }
        return "\(max(sliceCount, 1))"
    }

    var patientDisplayName: String {
        guard let name = metadata?.patientName, !name.isEmpty else {
            return "UNKNOWN"
        }
        return name
    }

    var patientDetails: String {
        let id = metadata?.patientID?.isEmpty == false ? metadata?.patientID ?? "—" : "—"
        let sex = metadata?.patientSex?.isEmpty == false ? metadata?.patientSex ?? "—" : "—"
        let age = metadata?.patientAge?.isEmpty == false ? metadata?.patientAge ?? "—" : "—"
        return "ID \(id) • \(sex)/\(age)"
    }

    var acquisitionDateTimeDisplay: String {
        metadata?.acquisitionDateTime ?? "—"
    }

    /// Reset only the imaging-related state (used when closing a study)
    func resetVolumeState() {
        volumeHandle = nil
        metadata = nil
        activeSeries = nil
        viewportOrientations = [:]
        sliceIndex = 0
        sliceCount = 0
        window = 350
        level = 40
        viewportZooms = [:]
        viewportPans = [:]
        isLoadingVolume = false
        lastError = nil
        lastErrorContext = nil
        currentStudyLabel = nil
        currentSeriesLabel = nil
        loadingStudyID = nil
        loadingSeriesID = nil
        errorStudyID = nil
        errorSeriesID = nil
        cineStates = [:]
    }

    /// Designated initializer.
    ///
    /// We rely on orientationIndex = 0 → .axial rather than
    /// storing .axial directly, to keep the Observation macro’s
    /// generated code free of enum case defaults that require an
    /// extra module import.
    init() {
        applyDefaultOrientations(for: layoutMode)
    }

    // MARK: - Layout defaults

    static func defaultOrientation(for layout: LayoutMode, index: Int) -> SliceOrientation {
        switch layout {
        case .oneUp:
            return .axial
        case .twoUp:
            return index == 1 ? .sagittal : .axial
        case .threeUp:
            switch index {
            case 1: return .sagittal
            case 2: return .coronal
            default: return .axial
            }
        case .fourUp:
            switch index {
            case 1: return .sagittal
            case 2: return .coronal
            default: return .axial
            }
        }
    }

    func applyDefaultOrientations(for layout: LayoutMode) {
        var defaults: [Int: SliceOrientation] = [:]
        for index in 0...layout.maxViewportIndex {
            defaults[index] = Self.defaultOrientation(for: layout, index: index)
        }
        viewportOrientations = defaults
    }

    func orientation(for index: Int) -> SliceOrientation {
        viewportOrientations[index] ?? Self.defaultOrientation(for: layoutMode, index: index)
    }

    func setOrientation(_ orientation: SliceOrientation, for index: Int) {
        viewportOrientations[index] = orientation
    }

    func zoom(for index: Int) -> CGFloat {
        viewportZooms[index] ?? Self.defaultZoom
    }

    func setZoom(_ zoom: CGFloat, for index: Int) {
        let clamped = min(max(zoom, Self.minZoom), Self.maxZoom)
        viewportZooms[index] = clamped
    }

    func resetZoom(for index: Int) {
        viewportZooms[index] = Self.defaultZoom
    }

    func pan(for index: Int) -> CGSize {
        viewportPans[index] ?? Self.defaultPan
    }

    func setPan(_ pan: CGSize, for index: Int) {
        viewportPans[index] = pan
    }

    func resetPan(for index: Int) {
        viewportPans[index] = Self.defaultPan
    }

    func crosshairPoint(for index: Int, imageSize: CGSize) -> CGPoint {
        let stored = viewportCrosshairPoints[index]
        let defaultPoint = CGPoint(x: imageSize.width * 0.5, y: imageSize.height * 0.5)
        return clampCrosshairPoint(stored ?? defaultPoint, imageSize: imageSize)
    }

    func setCrosshairPoint(_ point: CGPoint, for index: Int, imageSize: CGSize) {
        viewportCrosshairPoints[index] = clampCrosshairPoint(point, imageSize: imageSize)
    }

    func resetCrosshairPoints() {
        viewportCrosshairPoints.removeAll()
    }

    private func clampCrosshairPoint(_ point: CGPoint, imageSize: CGSize) -> CGPoint {
        let x = min(max(point.x, 0), max(imageSize.width, 0))
        let y = min(max(point.y, 0), max(imageSize.height, 0))
        return CGPoint(x: x, y: y)
    }

    func isImagingViewport(_ index: Int) -> Bool {
        !(layoutMode == .fourUp && index == 3)
    }

    var loadingTitle: String {
        if currentSeriesLabel != nil {
            return "Loading series…"
        }
        return "Loading study…"
    }

    var loadingDetail: String {
        if let seriesLabel = currentSeriesLabel, !seriesLabel.isEmpty {
            return seriesLabel
        }
        if let studyLabel = currentStudyLabel, !studyLabel.isEmpty {
            return studyLabel
        }
        return "Preparing volume…"
    }

    var activeViewportIndices: [Int] {
        Array(0...layoutMode.maxViewportIndex)
    }

    func cineState(for index: Int) -> ViewportCineState {
        cineStates[index] ?? ViewportCineState(isPlaying: false, fps: 15)
    }

    func setCineState(_ state: ViewportCineState, for index: Int) {
        cineStates[index] = state
    }

    func setCinePlaying(_ playing: Bool, for index: Int) {
        var state = cineState(for: index)
        state.isPlaying = playing
        cineStates[index] = state
    }

    func setCineFPS(_ fps: Double, for index: Int) {
        var state = cineState(for: index)
        state.fps = fps
        cineStates[index] = state
    }
}
