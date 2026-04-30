import Foundation
import SwiftUI
import Observation
import simd
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

/// 2D vs MPR vs 3D viewer mode
enum ViewerMode: String, CaseIterable, Identifiable {
    case twoD   = "2D"
    case mpr = "MPR"
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

enum MPRPane: String, CaseIterable, Identifiable {
    case axial
    case coronal
    case sagittal

    var id: String { rawValue }

    var orientation: SliceOrientation {
        switch self {
        case .axial:
            return .axial
        case .coronal:
            return .coronal
        case .sagittal:
            return .sagittal
        }
    }
}

enum MPRLayoutMode: String, CaseIterable, Identifiable {
    case triPlanar = "Side-by-side"
    case threeUp = "3-up"

    var id: String { rawValue }

    var next: MPRLayoutMode {
        switch self {
        case .triPlanar:
            return .threeUp
        case .threeUp:
            return .triPlanar
        }
    }
}

enum MPRPatientAxis: String, CaseIterable {
    case x
    case y
    case z

    var color: Color {
        switch self {
        case .x:
            return .red
        case .y:
            return .green
        case .z:
            return .blue
        }
    }
}

struct MPRCrosshairStyle {
    static func axes(for pane: MPRPane) -> (axisU: MPRPatientAxis, axisV: MPRPatientAxis) {
        switch pane {
        case .axial:
            return (.x, .y)
        case .coronal:
            return (.x, .z)
        case .sagittal:
            return (.y, .z)
        }
    }
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

struct ViewerWindowLevelPreset: Identifiable, Equatable, Hashable {
    enum Source: String, Equatable, Hashable {
        case dicom
        case standard
    }

    let id: String
    let name: String
    let window: Float
    let level: Float
    let source: Source

    var menuLabel: String {
        "\(name) (W \(Int(window.rounded())) / L \(Int(level.rounded())))"
    }
}

struct ViewerWindowLevelPresetSection: Identifiable, Equatable {
    let id: String
    let title: String
    let presets: [ViewerWindowLevelPreset]
}

struct ViewportSliceState: Equatable {
    var patientPoint: SIMD3<Double>?
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

    /// Window width and level (engine-space)
    var window: Float = 350
    var level: Float = 40

    /// Baseline window width and level for the currently loaded series.
    /// This is the source of truth used for initial display and Reset.
    var baselineWindow: Float = 350
    var baselineLevel: Float = 40

    /// DICOM-derived WW/WL presets extracted from the loaded series, if available.
    var dicomWindowLevelPresets: [ViewerWindowLevelPreset] = []

    // MARK: MPR (Tri-planar) State

    /// Shared patient-space crosshair point for tri-planar MPR.
    var mprCrosshairPoint: SIMD3<Double>? = nil

    /// Active pane for compact layouts.
    var mprActivePane: MPRPane = .axial

    /// Layout mode for MPR views. Only tri-planar is currently enabled.
    var mprLayoutMode: MPRLayoutMode = .triPlanar

    /// Mapping of tri-planar panes to orientations (axial/coronal/sagittal).
    static let defaultMPROrientationMap: [MPRPane: SliceOrientation] = [
        .axial: .axial,
        .coronal: .coronal,
        .sagittal: .sagittal
    ]

    var mprOrientationMap: [MPRPane: SliceOrientation] = ViewerState.defaultMPROrientationMap

    /// Interpolation mode for MPR (default = linear).
    var mprInterpolation: MPRInterpolation = .linear

    /// Reserved slab thickness (mm) for future thick MPR support.
    var mprSlabThickness: Double = 0.0

    // MARK: Zoom state

    static let defaultZoom: CGFloat = 1.0
    static let minZoom: CGFloat = 0.5
    static let maxZoom: CGFloat = 5.0
    static let defaultPan: CGSize = .zero

    private var viewportZooms: [Int: CGFloat] = [:]
    private var viewportPans: [Int: CGSize] = [:]
    private var viewportSliceStates: [Int: ViewportSliceState] = [:]

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

    // MARK: - Overlay display helpers

    var seriesTitle: String {
        if let series = activeSeries, !series.seriesDescription.isEmpty {
            return series.seriesDescription
        }
        if let label = currentSeriesTitleFallback {
            return label
        }
        if let description = metadata?.seriesDescription, !description.isEmpty {
            return description
        }
        if let study = metadata?.studyDescription, !study.isEmpty {
            return study
        }
        if let studyLabel = currentStudyLabel, !studyLabel.isEmpty {
            return studyLabel
        }
        return metadata?.modality ?? "Series"
    }

    var seriesSubtitle: String {
        if let series = activeSeries {
            return "SER \(series.seriesNumber)  \(series.modality)"
        }
        if let label = currentSeriesSubtitleFallback {
            return label
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
        if let numberOfInstances = metadata?.numberOfInstances, numberOfInstances > 0 {
            return "\(numberOfInstances)"
        }
        return "1"
    }

    var patientDisplayName: String {
        if let name = metadata?.patientName, !name.isEmpty {
            return name
        }
        if let studyLabel = currentStudyLabel, !studyLabel.isEmpty {
            return studyLabel
        }
        return "UNKNOWN"
    }

    var patientDetails: String {
        let id = metadata?.patientID?.isEmpty == false ? metadata?.patientID ?? "—" : "—"
        let sex = metadata?.patientSex?.isEmpty == false ? metadata?.patientSex ?? "—" : "—"
        let age = metadata?.patientAge?.isEmpty == false ? metadata?.patientAge ?? "—" : "—"
        if id == "—" && sex == "—" && age == "—" {
            return metadata?.studyDescription ?? "—"
        }
        return "ID \(id) • \(sex)/\(age)"
    }

    var acquisitionDateTimeDisplay: String {
        if let acquisition = metadata?.acquisitionDateTime, !acquisition.isEmpty {
            return acquisition
        }
        if let studyDate = metadata?.studyDate, !studyDate.isEmpty {
            return studyDate
        }
        return "—"
    }

    private var currentSeriesTitleFallback: String? {
        guard let label = currentSeriesLabel?.trimmingCharacters(in: .whitespacesAndNewlines),
              !label.isEmpty else {
            return nil
        }
        if let range = label.range(of: " (SER ") {
            return String(label[..<range.lowerBound])
        }
        return label
    }

    private var currentSeriesSubtitleFallback: String? {
        guard let label = currentSeriesLabel?.trimmingCharacters(in: .whitespacesAndNewlines),
              !label.isEmpty else {
            return nil
        }
        if let range = label.range(of: " (SER "),
           label.hasSuffix(")") {
            let suffixStart = label.index(after: range.lowerBound)
            return String(label[suffixStart..<label.index(before: label.endIndex)])
        }
        if let studyLabel = currentStudyLabel, !studyLabel.isEmpty {
            return studyLabel
        }
        return label
    }

    /// Reset only the imaging-related state (used when closing a study)
    func resetVolumeState() {
        volumeHandle = nil
        metadata = nil
        activeSeries = nil
        viewportOrientations = [:]
        window = 350
        level = 40
        baselineWindow = 350
        baselineLevel = 40
        dicomWindowLevelPresets = []
        mprCrosshairPoint = nil
        mprActivePane = .axial
        mprOrientationMap = Self.defaultMPROrientationMap
        mprInterpolation = .linear
        mprSlabThickness = 0.0
        viewportZooms = [:]
        viewportPans = [:]
        viewportSliceStates = [:]
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

    func sliceState(for index: Int) -> ViewportSliceState {
        viewportSliceStates[index] ?? ViewportSliceState()
    }

    func patientPoint(for index: Int) -> SIMD3<Double>? {
        sliceState(for: index).patientPoint
    }

    func setPatientPoint(_ point: SIMD3<Double>?, for index: Int) {
        viewportSliceStates[index] = ViewportSliceState(patientPoint: point)
    }

    func resetViewportSliceStates() {
        viewportSliceStates.removeAll()
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
