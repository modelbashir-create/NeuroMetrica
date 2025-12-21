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


    // MARK: - Init

    init() {}
}

// MARK: - Static default

extension AppSettings {
    /// Reasonable static default instance.
    static let `default` = AppSettings()
}
