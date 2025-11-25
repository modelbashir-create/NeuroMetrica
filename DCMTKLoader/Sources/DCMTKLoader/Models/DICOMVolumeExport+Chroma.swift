#if canImport(ChromaImagingKit)
import ChromaImagingKit

public extension DICOMVolumeExport {
    /// Convenience conversion into ChromaImagingKit's CIImageVolume.
    /// Preserves the flattened z–y–x voxel layout and spacing tuple.
    func toCIImageVolume() -> CIImageVolume {
        CIImageVolume(
            width: width,
            height: height,
            depth: depth,
            spacing: spacing,
            voxels: voxels
        )
    }
}
#endif
