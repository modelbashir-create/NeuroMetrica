import Foundation

/// DICOM IO backend preference for ITK.
public enum DicomBackend: String, CaseIterable, Sendable {
    /// Prefer DCMTK, fall back to GDCM if unavailable.
    case dcmtkPreferred
    /// Force GDCM.
    case gdcm
}

/// Rendering policy for spatial orientation handling.
public enum RenderingOrientationPolicy: String, Sendable {
    /// Preserve native orientation exactly as provided by ITK (no reorientation).
    case nativeOrientationOnly
}

/// Preferred rendering backend for slice/MPR rendering.
public enum RenderingBackend: String, Sendable {
    case automatic
    case cpu
    case gpu
}

/// Configuration for ChromaEngine behavior.
public struct ChromaEngineConfig: Sendable, Equatable {
    public var dicomBackend: DicomBackend
    public var renderingBackend: RenderingBackend
    public var renderingOrientationPolicy: RenderingOrientationPolicy
    public var enableGPUDebugComparison: Bool

    /// Effective GPU usage derived from the backend policy.
    public var useGPUSliceRendering: Bool {
        get { renderingBackend != .cpu }
        set { renderingBackend = newValue ? .gpu : .cpu }
    }

    public init(
        dicomBackend: DicomBackend = .dcmtkPreferred,
        renderingBackend: RenderingBackend = .automatic,
        renderingOrientationPolicy: RenderingOrientationPolicy = .nativeOrientationOnly,
        enableGPUDebugComparison: Bool = false
    ) {
        self.dicomBackend = dicomBackend
        self.renderingBackend = renderingBackend
        self.renderingOrientationPolicy = renderingOrientationPolicy
        self.enableGPUDebugComparison = enableGPUDebugComparison
    }

    public static let standard = ChromaEngineConfig()
}

public extension ChromaEngineConfig {
    init(
        dicomBackend: DicomBackend = .dcmtkPreferred,
        useGPUSliceRendering: Bool,
        renderingOrientationPolicy: RenderingOrientationPolicy = .nativeOrientationOnly,
        enableGPUDebugComparison: Bool = false
    ) {
        self.init(
            dicomBackend: dicomBackend,
            renderingBackend: useGPUSliceRendering ? .gpu : .cpu,
            renderingOrientationPolicy: renderingOrientationPolicy,
            enableGPUDebugComparison: enableGPUDebugComparison
        )
    }
}
