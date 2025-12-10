import Foundation
import SwiftUI
import Observation
import ChromaImagingCore   // for SliceOrientation (axial / coronal / sagittal)

// MARK: - Layout & Viewer Enums

enum LayoutMode: String, CaseIterable, Identifiable {
    case oneUp   = "1-up"
    case twoUp   = "2-up"
    case threeUp = "3-up"
    case fourUp  = "4-up"

    var id: String { rawValue }

    var next: LayoutMode {
        switch self {
        case .oneUp:   return .twoUp
        case .twoUp:   return .threeUp
        case .threeUp: return .fourUp
        case .fourUp:  return .oneUp
        }
    }

    var maxViewportIndex: Int {
        switch self {
        case .oneUp:   return 0
        case .twoUp:   return 1
        case .threeUp: return 2
        case .fourUp:  return 3
        }
    }
}

enum ViewerMode: String, CaseIterable, Identifiable {
    case twoD   = "2D"
    case threeD = "3D"

    var id: String { rawValue }
}

enum ThreeDSubMode: String, CaseIterable, Identifiable {
    case mpr = "MPR"
    case vr  = "VR"
    case mip = "MIP"

    var id: String { rawValue }
}

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


// MARK: - Heritage PACS Theme (Diagnostic Black Preserved)

struct HeritagePACSTheme {
    // Core surfaces - heritage black for medical imaging (clinically required)
    static let canvasBackground   = Color.black
    static let viewportBackground = Color(red: 0.02, green: 0.02, blue: 0.04)

    // Active viewport accent
    static let activeViewportBorder = Color(red: 0.30, green: 0.80, blue: 0.40)

    // Overlay text
    static let overlayTextPrimary   = Color.white
    static let overlayTextSecondary = Color(white: 0.7)

    // PHI highlight
    static let phiHighlightYellow = Color(red: 1.0, green: 0.86, blue: 0.45)

    // Annotations
    static let crosshairColor   = Color(red: 0.65, green: 0.90, blue: 1.0)
    static let measurementColor = Color(red: 0.10, green: 0.78, blue: 0.88)

    // Status indicators
    static let statusOK      = Color(red: 0.30, green: 0.80, blue: 0.40)
    static let statusWarning = Color(red: 1.00, green: 0.75, blue: 0.30)
    static let statusError   = Color(red: 1.00, green: 0.35, blue: 0.35)
}


// MARK: - Observable Viewer State (UI + Imaging)

@Observable
@MainActor
final class ViewerState {

    // MARK: UI / Layout State

    var layoutMode: LayoutMode = .oneUp
    var viewerMode: ViewerMode = .twoD
    var threeDMode: ThreeDSubMode = .mpr
    var activeViewportIndex: Int = 0
    var activeTool: ViewerTool = .windowLevel

    // Sheet presentation states
    var showExportSheet: Bool = false
    var showSettingsSheet: Bool = false

    /// Active viewport index, clamped into the valid range for the current layout
    var clampedActiveIndex: Int {
        min(max(activeViewportIndex, 0), layoutMode.maxViewportIndex)
    }

    func cycleLayout() {
        layoutMode = layoutMode.next
        if activeViewportIndex > layoutMode.maxViewportIndex {
            activeViewportIndex = 0
        }
    }

    func toggleViewerMode() {
        viewerMode = (viewerMode == .twoD) ? .threeD : .twoD
    }

    func setLayout(_ mode: LayoutMode) {
        layoutMode = mode
        if activeViewportIndex > layoutMode.maxViewportIndex {
            activeViewportIndex = 0
        }
    }


    // MARK: Imaging State (Volume / Slices / WWL)

    /// Handle returned by `ChromaEngineBridge` after loading a volume
    var volumeHandle: VolumeHandle? = nil

    /// Current orthogonal orientation (axial / coronal / sagittal)
    var orientation: SliceOrientation = .axial

    /// Zero-based slice index within the current orientation
    var sliceIndex: Int = 0

    /// Total number of slices available in the current orientation
    var sliceCount: Int = 0

    /// Window width and level (Hounsfield etc., engine-space)
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

    /// Slice index clamped into `[0, sliceCount - 1]`
    var clampedSliceIndex: Int {
        guard sliceCount > 0 else { return 0 }
        return max(0, min(sliceIndex, sliceCount - 1))
    }

    /// Reset only the imaging-related state (used when closing a study)
    func resetVolumeState() {
        volumeHandle = nil
        orientation = .axial
        sliceIndex = 0
        sliceCount = 0
        window = 350
        level = 40
        isLoading = false
        lastError = nil
    }
}
