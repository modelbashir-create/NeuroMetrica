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

/// Configuration for ChromaEngine behavior.
public struct ChromaEngineConfig: Sendable, Equatable {
    public var dicomBackend: DicomBackend
    public var useGPUSliceRendering: Bool
    public var renderingOrientationPolicy: RenderingOrientationPolicy
    public var enableGPUDebugComparison: Bool

    public init(
        dicomBackend: DicomBackend = .dcmtkPreferred,
        useGPUSliceRendering: Bool = false,
        renderingOrientationPolicy: RenderingOrientationPolicy = .nativeOrientationOnly,
        enableGPUDebugComparison: Bool = false
    ) {
        self.dicomBackend = dicomBackend
        self.useGPUSliceRendering = useGPUSliceRendering
        self.renderingOrientationPolicy = renderingOrientationPolicy
        self.enableGPUDebugComparison = enableGPUDebugComparison
    }

    public static let standard = ChromaEngineConfig()
}
