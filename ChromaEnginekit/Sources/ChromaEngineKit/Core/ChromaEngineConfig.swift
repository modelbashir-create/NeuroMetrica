import Foundation

/// DICOM IO backend preference for ITK.
public enum DicomBackend: String, CaseIterable, Sendable {
    /// Prefer DCMTK, fall back to GDCM if unavailable.
    case dcmtkPreferred
    /// Force GDCM.
    case gdcm
}

/// Configuration for ChromaEngine behavior.
public struct ChromaEngineConfig: Sendable, Equatable {
    public var dicomBackend: DicomBackend

    public init(dicomBackend: DicomBackend = .dcmtkPreferred) {
        self.dicomBackend = dicomBackend
    }

    public static let standard = ChromaEngineConfig()
}
