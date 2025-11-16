
import Foundation
import ChromaImagingKit

/// Holds the current state of the viewer: which volume, which slice,
/// which orientation, and current window/level.
struct ViewerState {
    var volume: CIImageVolume?
    var orientation: SliceOrientation
    var sliceIndex: Int
    var sliceCount: Int
    var window: Float
    var level: Float

    // Default WW/WL – you can tweak these later.
    static let defaultWindow: Float = 400
    static let defaultLevel: Float = 40

    /// Convenience factory for an “empty” viewer with no volume loaded yet.
    static func empty() -> ViewerState {
        ViewerState(
            volume: nil,
            orientation: .axial,
            sliceIndex: 0,
            sliceCount: 0,
            window: defaultWindow,
            level: defaultLevel
        )
    }

    /// Returns a new state with an updated volume and (optionally) orientation,
    /// recomputing sliceCount and clamping sliceIndex.
    func updating(
        volume newVolume: CIImageVolume?,
        orientation newOrientation: SliceOrientation? = nil
    ) -> ViewerState {
        let orientation = newOrientation ?? self.orientation

        let newSliceCount: Int
        if let volume = newVolume {
            switch orientation {
            case .axial:
                newSliceCount = volume.depth
            case .coronal:
                newSliceCount = volume.height
            case .sagittal:
                newSliceCount = volume.width
            }
        } else {
            newSliceCount = 0
        }

        let clampedIndex = min(max(sliceIndex, 0), max(newSliceCount - 1, 0))

        return ViewerState(
            volume: newVolume,
            orientation: orientation,
            sliceIndex: clampedIndex,
            sliceCount: newSliceCount,
            window: window,
            level: level
        )
    }
}
