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
    @Published var showDebugOverlay: Bool = false

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
