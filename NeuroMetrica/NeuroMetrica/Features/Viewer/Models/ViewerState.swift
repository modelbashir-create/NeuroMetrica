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
    case zoom        = "Zoom"
    case measure     = "Measure"
    case cine        = "Cine"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .windowLevel: return "slider.horizontal.3"
        case .pan:         return "hand.draw"
        case .zoom:        return "plus.magnifyingglass"
        case .measure:     return "ruler"
        case .cine:        return "play.fill"
        }
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
    var activeTool: ViewerTool = .windowLevel

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
    }


    // MARK: Imaging State (Volume / Slices / WWL)

    /// Handle returned by ChromaEngine after loading a volume
    var volumeHandle: VolumeHandle? = nil

    /// Internal tracked index for orientation:
    /// 0 = axial, 1 = coronal, 2 = sagittal.
    ///
    /// This is what the Observation macro actually tracks, so the
    /// default value is just an Int (no dependency on .axial in
    /// generated macro files).
    private var orientationIndex: Int = 0

    /// Public orthogonal orientation (axial / coronal / sagittal).
    ///
    /// This is a computed façade over orientationIndex so that UI
    /// and engine code work with SliceOrientation while the Observation
    /// system only sees an Int default.
    var orientation: SliceOrientation {
        get {
            switch orientationIndex {
            case 1: return .coronal
            case 2: return .sagittal
            default: return .axial
            }
        }
        set {
            switch newValue {
            case .axial:
                orientationIndex = 0
            case .coronal:
                orientationIndex = 1
            case .sagittal:
                orientationIndex = 2
            @unknown default:
                orientationIndex = 0
            }
        }
    }

    /// Zero-based slice index within the current orientation
    var sliceIndex: Int = 0

    /// Total number of slices available in the current orientation
    var sliceCount: Int = 0

    /// Window width and level (engine-space)
    var window: Float = 350
    var level: Float = 40

    /// Indicates an async load / reslice is in progress
    var isLoading: Bool = false

    /// Last user-visible error message, if any
    var lastError: String? = nil

    /// Whether a volume is currently loaded
    var hasVolume: Bool {
        volumeHandle != nil
    }

    /// Slice index clamped into [0, sliceCount - 1]
    var clampedSliceIndex: Int {
        guard sliceCount > 0 else { return 0 }
        return max(0, min(sliceIndex, sliceCount - 1))
    }

    /// Reset only the imaging-related state (used when closing a study)
    func resetVolumeState() {
        volumeHandle = nil
        orientationIndex = 0   // back to axial
        sliceIndex = 0
        sliceCount = 0
        window = 350
        level = 40
        isLoading = false
        lastError = nil
    }

    /// Designated initializer.
    ///
    /// We rely on orientationIndex = 0 → .axial rather than
    /// storing .axial directly, to keep the Observation macro’s
    /// generated code free of enum case defaults that require an
    /// extra module import.
    init() {}
}
