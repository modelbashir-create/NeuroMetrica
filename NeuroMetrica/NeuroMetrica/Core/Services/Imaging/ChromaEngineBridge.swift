import Foundation
import ChromaImagingKit

/// Thin wrapper around ChromaImagingKit for the app.
/// Responsible for:
/// - Loading volumes (e.g. NIfTI) via ChromaEngine.
/// - Producing WW/WL-processed slices via ChromaEngine.
final class ChromaEngineBridge {

    enum BridgeError: Error {
        case invalidSliceIndex
    }

    private let engine: ChromaEngine

    init(engine: ChromaEngine = ChromaEngine()) {
        self.engine = engine
    }

    func updateBackend(_ backend: ChromaProcessingBackend) {
        engine.backend = backend
    }

    /// Load a NIfTI (.nii or .nii.gz) file into a CIImageVolume using ChromaEngine.
    ///
    /// This is async to play nicely with async/await call sites, even though the current
    /// implementation is synchronous under the hood. If we later move the work to a
    /// background task, the signature here does not need to change.
    func loadNIfTI(from url: URL) async throws -> CIImageVolume {
        return try engine.loadNIfTI(at: url)
    }

    /// Extracts a slice from the given volume and applies window/level.
    ///
    /// - Parameters:
    ///   - volume: The 3D volume to slice.
    ///   - orientation: Axial, coronal, or sagittal.
    ///   - index: Slice index along the chosen orientation.
    ///   - window: WW value.
    ///   - level: WL value.
    ///
    /// - Returns: A CIImage2D with pixels normalized to [0, 1].
    func makeSlice(
        volume: CIImageVolume,
        orientation: SliceOrientation,
        index: Int,
        window: Float,
        level: Float
    ) throws -> CIImage2D {

        // Bounds check for the requested index at the app/bridge level
        let maxIndex: Int
        switch orientation {
        case .axial:
            maxIndex = volume.depth - 1
        case .coronal:
            maxIndex = volume.height - 1
        case .sagittal:
            maxIndex = volume.width - 1
        }

        guard index >= 0, index <= maxIndex else {
            throw BridgeError.invalidSliceIndex
        }

        // Delegate the actual slice extraction + WW/WL to ChromaEngine.
        return try engine.makeSlice(
            from: volume,
            orientation: orientation,
            index: index,
            window: window,
            level: level
        )
    }
}
