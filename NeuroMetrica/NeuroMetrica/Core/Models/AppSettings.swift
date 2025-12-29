//
//  AppSettings.swift
//  NeuroMetrica
//
//  Global, app-wide preferences and flags.
//  Observable model (no dependency on ChromaEngineKit / ChromaImagingCore).
//

import Foundation
import Combine

/// High-level choice of which processing backend to use in the viewer.
///
/// NOTE:
/// - `.native`       → use ChromaEngineKit's native backends (Metal / vDSP).
/// - `.itk`          → use ITK-backed backends where available.
/// - `.verification` → run both in parallel for developer comparison.
public enum ProcessingBackend: String, CaseIterable, Identifiable, Codable {
    case native
    case itk
    case verification

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .native:       return "Native"
        case .itk:          return "ITK"
        case .verification: return "Verify (Both)"
        }
    }
}

/// Preferred DICOM IO backend.
///
/// - dcmtk: Prefer DCMTK; fall back to GDCM if unavailable.
/// - gdcm: Force GDCM for DICOM series loading.
public enum DicomBackendPreference: String, CaseIterable, Identifiable, Codable {
    case dcmtk
    case gdcm

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .dcmtk:
            return "DCMTK (Preferred)"
        case .gdcm:
            return "GDCM"
        }
    }
}

/// Global UI + viewer preferences for NeuroMetrica.
///
/// This type is an observable reference type so it can be injected via
/// `@EnvironmentObject` and shared across the app. Persistence (Codable
/// or a dedicated store) can be added later without affecting callers.
@MainActor
final class AppSettings: ObservableObject {

    // MARK: - Viewer layout / mode defaults

    /// Raw string backing the default layout mode (1-up, 2-up, etc.).
    /// Stored as a primitive string so Core stays decoupled from viewer enums.
    @Published var defaultLayoutModeRaw: String = "1-up"

    /// Raw string backing the default viewer mode (2D vs 3D).
    @Published var defaultViewerModeRaw: String = "2D"

    /// Raw string backing the default 3D mode (MPR / VR / MIP).
    @Published var defaultThreeDModeRaw: String = "MPR"

    // MARK: - Window/Level defaults

    /// Default window width for new studies.
    @Published var defaultWindow: Double = 350

    /// Default window level for new studies.
    @Published var defaultLevel: Double = 40

    // MARK: - Window/Level interaction tuning

    /// Fraction of starting window used as Level change per point of drag.
    @Published var windowLevelDragLevelScale: Double = 0.003 {
        didSet {
            let clamped = persistClampedDouble(
                windowLevelDragLevelScale,
                min: 0.0005,
                max: 0.02,
                key: Keys.windowLevelDragLevelScale
            )
            if clamped != windowLevelDragLevelScale {
                windowLevelDragLevelScale = clamped
            }
        }
    }

    /// Ratio of Window sensitivity relative to Level (default = 2x slower).
    @Published var windowLevelDragWindowToLevelRatio: Double = 0.5 {
        didSet {
            let clamped = persistClampedDouble(
                windowLevelDragWindowToLevelRatio,
                min: 0.2,
                max: 1.0,
                key: Keys.windowLevelDragWindowToLevelRatio
            )
            if clamped != windowLevelDragWindowToLevelRatio {
                windowLevelDragWindowToLevelRatio = clamped
            }
        }
    }

    /// Axis lock threshold (dominant axis must exceed the other by this ratio).
    @Published var windowLevelDragAxisLockThreshold: Double = 0.35 {
        didSet {
            let clamped = persistClampedDouble(
                windowLevelDragAxisLockThreshold,
                min: 0.05,
                max: 1.0,
                key: Keys.windowLevelDragAxisLockThreshold
            )
            if clamped != windowLevelDragAxisLockThreshold {
                windowLevelDragAxisLockThreshold = clamped
            }
        }
    }

    /// Gamma curve for WW/WL drag response (1.0 = linear, >1 accelerates).
    @Published var windowLevelDragResponseGamma: Double = 1.15 {
        didSet {
            let clamped = persistClampedDouble(
                windowLevelDragResponseGamma,
                min: 1.0,
                max: 1.5,
                key: Keys.windowLevelDragResponseGamma
            )
            if clamped != windowLevelDragResponseGamma {
                windowLevelDragResponseGamma = clamped
            }
        }
    }

    /// Dead zone in points before WW/WL drag starts applying.
    @Published var windowLevelDragDeadZonePoints: Double = 3.0 {
        didSet {
            let clamped = persistClampedDouble(
                windowLevelDragDeadZonePoints,
                min: 0.0,
                max: 8.0,
                key: Keys.windowLevelDragDeadZonePoints
            )
            if clamped != windowLevelDragDeadZonePoints {
                windowLevelDragDeadZonePoints = clamped
            }
        }
    }

    /// Preset snap tolerance as a fraction of the preset values.
    @Published var windowLevelPresetSnapTolerance: Double = 0.08 {
        didSet {
            let clamped = persistClampedDouble(
                windowLevelPresetSnapTolerance,
                min: 0.02,
                max: 0.2,
                key: Keys.windowLevelPresetSnapTolerance
            )
            if clamped != windowLevelPresetSnapTolerance {
                windowLevelPresetSnapTolerance = clamped
            }
        }
    }

    /// Preset snap strength (0 = none, 1 = full snap).
    @Published var windowLevelPresetSnapStrength: Double = 0.6 {
        didSet {
            let clamped = persistClampedDouble(
                windowLevelPresetSnapStrength,
                min: 0.0,
                max: 1.0,
                key: Keys.windowLevelPresetSnapStrength
            )
            if clamped != windowLevelPresetSnapStrength {
                windowLevelPresetSnapStrength = clamped
            }
        }
    }

    /// Fine-adjustment scale when holding Option during WW/WL drag.
    @Published var windowLevelDragFineAdjustmentScale: Double = 0.25 {
        didSet {
            let clamped = persistClampedDouble(
                windowLevelDragFineAdjustmentScale,
                min: 0.1,
                max: 0.5,
                key: Keys.windowLevelDragFineAdjustmentScale
            )
            if clamped != windowLevelDragFineAdjustmentScale {
                windowLevelDragFineAdjustmentScale = clamped
            }
        }
    }

    // MARK: - UI / UX flags

    /// Whether to show crosshairs in new viewports by default.
    @Published var showCrosshairByDefault: Bool = true

    /// Whether to show patient demographics/PHI overlays by default.
    @Published var showPatientInfoByDefault: Bool = true

    /// Whether to auto-play cine when a stack is first loaded.
    @Published var autoPlayCineOnLoad: Bool = false

    /// Default cine frame rate (frames per second).
    @Published var defaultCineFrameRate: Double = 15

    // MARK: - Dev / debug flags

    /// Whether to show the developer debug overlay by default.
    @Published var showDebugOverlay: Bool = false {
        didSet { userDefaults.set(showDebugOverlay, forKey: Keys.showDebugOverlay) }
    }

    /// Whether PHI is allowed in diagnostics/metadata views (DevTools only).
    @Published var showPHIInDiagnostics: Bool = false {
        didSet { userDefaults.set(showPHIInDiagnostics, forKey: Keys.showPHIInDiagnostics) }
    }

    /// Which processing backend the viewer should use.
    @Published var processingBackend: ProcessingBackend = .native

    /// Preferred DICOM IO backend.
    @Published var dicomBackendPreference: DicomBackendPreference = .dcmtk

    // MARK: - Developer Tools (scroll tuning)

    /// Points of scroll per slice step (higher = slower / more precise).
    @Published var sliceScrollBaseThreshold: Double = 36 {
        didSet {
            guard !isClampingScrollSettings else { return }
            let clamped = persistClampedDouble(sliceScrollBaseThreshold, min: 20, max: 80, key: Keys.sliceScrollBaseThreshold)
            if clamped != sliceScrollBaseThreshold {
                isClampingScrollSettings = true
                sliceScrollBaseThreshold = clamped
                isClampingScrollSettings = false
            }
        }
    }

    /// Speed multiplier for Shift+scroll.
    @Published var sliceScrollFastMultiplier: Int = 3 {
        didSet {
            guard !isClampingScrollSettings else { return }
            let clamped = persistClampedInt(sliceScrollFastMultiplier, min: 2, max: 6, key: Keys.sliceScrollFastMultiplier)
            if clamped != sliceScrollFastMultiplier {
                isClampingScrollSettings = true
                sliceScrollFastMultiplier = clamped
                isClampingScrollSettings = false
            }
        }
    }

    /// Cap on total slices advanced per scroll event.
    @Published var sliceScrollMaxSlicesPerEvent: Int = 6 {
        didSet {
            guard !isClampingScrollSettings else { return }
            let clamped = persistClampedInt(sliceScrollMaxSlicesPerEvent, min: 2, max: 12, key: Keys.sliceScrollMaxSlicesPerEvent)
            if clamped != sliceScrollMaxSlicesPerEvent {
                isClampingScrollSettings = true
                sliceScrollMaxSlicesPerEvent = clamped
                isClampingScrollSettings = false
            }
        }
    }

    /// Momentum scale for trackpad scroll (lower = shorter/less glide).
    @Published var sliceScrollMomentumScale: Double = 0.11 {
        didSet {
            guard !isClampingScrollSettings else { return }
            let clamped = persistClampedDouble(sliceScrollMomentumScale, min: 0.01, max: 1.0, key: Keys.sliceScrollMomentumScale)
            if clamped != sliceScrollMomentumScale {
                isClampingScrollSettings = true
                sliceScrollMomentumScale = clamped
                isClampingScrollSettings = false
            }
        }
    }

    /// Page Up/Down and Option+Up/Down jump size.
    @Published var sliceScrollPageJumpSize: Int = 10 {
        didSet {
            guard !isClampingScrollSettings else { return }
            let clamped = persistClampedInt(sliceScrollPageJumpSize, min: 5, max: 30, key: Keys.sliceScrollPageJumpSize)
            if clamped != sliceScrollPageJumpSize {
                isClampingScrollSettings = true
                sliceScrollPageJumpSize = clamped
                isClampingScrollSettings = false
            }
        }
    }

    /// Whether Shift+scroll uses the fast multiplier.
    @Published var sliceScrollUseShiftFastMode: Bool = true {
        didSet { userDefaults.set(sliceScrollUseShiftFastMode, forKey: Keys.sliceScrollUseShiftFastMode) }
    }


    // MARK: - Init

    private let userDefaults: UserDefaults = .standard
    private var isClampingScrollSettings = false

    init() {
        sliceScrollBaseThreshold = loadDouble(key: Keys.sliceScrollBaseThreshold, defaultValue: sliceScrollBaseThreshold)
        sliceScrollFastMultiplier = loadInt(key: Keys.sliceScrollFastMultiplier, defaultValue: sliceScrollFastMultiplier)
        sliceScrollMaxSlicesPerEvent = loadInt(key: Keys.sliceScrollMaxSlicesPerEvent, defaultValue: sliceScrollMaxSlicesPerEvent)
        sliceScrollMomentumScale = loadDouble(key: Keys.sliceScrollMomentumScale, defaultValue: sliceScrollMomentumScale)
        sliceScrollPageJumpSize = loadInt(key: Keys.sliceScrollPageJumpSize, defaultValue: sliceScrollPageJumpSize)
        sliceScrollUseShiftFastMode = loadBool(key: Keys.sliceScrollUseShiftFastMode, defaultValue: sliceScrollUseShiftFastMode)
        showDebugOverlay = loadBool(key: Keys.showDebugOverlay, defaultValue: showDebugOverlay)
        showPHIInDiagnostics = loadBool(key: Keys.showPHIInDiagnostics, defaultValue: showPHIInDiagnostics)
        windowLevelDragLevelScale = loadDouble(
            key: Keys.windowLevelDragLevelScale,
            defaultValue: windowLevelDragLevelScale
        )
        windowLevelDragWindowToLevelRatio = loadDouble(
            key: Keys.windowLevelDragWindowToLevelRatio,
            defaultValue: windowLevelDragWindowToLevelRatio
        )
        windowLevelDragAxisLockThreshold = loadDouble(
            key: Keys.windowLevelDragAxisLockThreshold,
            defaultValue: windowLevelDragAxisLockThreshold
        )
        windowLevelDragResponseGamma = loadDouble(
            key: Keys.windowLevelDragResponseGamma,
            defaultValue: windowLevelDragResponseGamma
        )
        windowLevelDragDeadZonePoints = loadDouble(
            key: Keys.windowLevelDragDeadZonePoints,
            defaultValue: windowLevelDragDeadZonePoints
        )
        windowLevelPresetSnapTolerance = loadDouble(
            key: Keys.windowLevelPresetSnapTolerance,
            defaultValue: windowLevelPresetSnapTolerance
        )
        windowLevelPresetSnapStrength = loadDouble(
            key: Keys.windowLevelPresetSnapStrength,
            defaultValue: windowLevelPresetSnapStrength
        )
        windowLevelDragFineAdjustmentScale = loadDouble(
            key: Keys.windowLevelDragFineAdjustmentScale,
            defaultValue: windowLevelDragFineAdjustmentScale
        )
    }
}

// MARK: - Persistence

private enum Keys {
    static let sliceScrollBaseThreshold = "appSettings.sliceScrollBaseThreshold"
    static let sliceScrollFastMultiplier = "appSettings.sliceScrollFastMultiplier"
    static let sliceScrollMaxSlicesPerEvent = "appSettings.sliceScrollMaxSlicesPerEvent"
    static let sliceScrollMomentumScale = "appSettings.sliceScrollMomentumScale"
    static let sliceScrollPageJumpSize = "appSettings.sliceScrollPageJumpSize"
    static let sliceScrollUseShiftFastMode = "appSettings.sliceScrollUseShiftFastMode"
    static let windowLevelDragLevelScale = "appSettings.windowLevelDragLevelScale"
    static let windowLevelDragWindowToLevelRatio = "appSettings.windowLevelDragWindowToLevelRatio"
    static let windowLevelDragAxisLockThreshold = "appSettings.windowLevelDragAxisLockThreshold"
    static let windowLevelDragResponseGamma = "appSettings.windowLevelDragResponseGamma"
    static let windowLevelDragDeadZonePoints = "appSettings.windowLevelDragDeadZonePoints"
    static let windowLevelPresetSnapTolerance = "appSettings.windowLevelPresetSnapTolerance"
    static let windowLevelPresetSnapStrength = "appSettings.windowLevelPresetSnapStrength"
    static let windowLevelDragFineAdjustmentScale = "appSettings.windowLevelDragFineAdjustmentScale"
    static let showDebugOverlay = "appSettings.showDebugOverlay"
    static let showPHIInDiagnostics = "appSettings.showPHIInDiagnostics"
}

private extension AppSettings {
    func loadDouble(key: String, defaultValue: Double) -> Double {
        guard let value = userDefaults.object(forKey: key) as? Double else { return defaultValue }
        return value
    }

    func loadInt(key: String, defaultValue: Int) -> Int {
        guard let value = userDefaults.object(forKey: key) as? Int else { return defaultValue }
        return value
    }

    func loadBool(key: String, defaultValue: Bool) -> Bool {
        guard let value = userDefaults.object(forKey: key) as? Bool else { return defaultValue }
        return value
    }

    func persistClampedDouble(_ value: Double, min: Double, max: Double, key: String) -> Double {
        let clamped = Swift.min(Swift.max(value, min), max)
        userDefaults.set(clamped, forKey: key)
        return clamped
    }

    func persistClampedInt(_ value: Int, min: Int, max: Int, key: String) -> Int {
        let clamped = Swift.min(Swift.max(value, min), max)
        userDefaults.set(clamped, forKey: key)
        return clamped
    }
}

// MARK: - Developer Tools helpers

extension AppSettings {
    func resetScrollTuningToDefaults() {
        sliceScrollBaseThreshold = 36
        sliceScrollFastMultiplier = 3
        sliceScrollMaxSlicesPerEvent = 6
        sliceScrollMomentumScale = 0.11
        sliceScrollPageJumpSize = 10
        sliceScrollUseShiftFastMode = true
    }
}

// MARK: - Static default

extension AppSettings {
    /// Reasonable static default instance.
    static let `default` = AppSettings()
}
