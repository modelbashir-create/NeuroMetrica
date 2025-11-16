import Foundation
import CNifti

public enum NIfTILoaderError: Error {
    case loadFailed
    case invalidVolume
    case missingData
}

/// Swift wrapper around the CNifti C bridge (NiftiBridge.c).
/// Responsible for:
/// - calling `nm_nifti_load`
/// - validating dimensions
/// - copying voxel data into Swift memory
/// - returning a CIImageVolume for the rest of the engine.
public final class NIfTILoader {

    public init() {}

    public func loadVolume(from url: URL) throws -> CIImageVolume {
        let path = url.path

        // Call into the C bridge. `nm_nifti_load` returns a heap-allocated NM_NiftiVolume*.
        guard let volumePtr: UnsafeMutablePointer<NM_NiftiVolume> = path.withCString({ cPath in
            nm_nifti_load(cPath)
        }) else {
            throw NIfTILoaderError.loadFailed
        }

        let vol = volumePtr.pointee

        // Always free the C-side volume when we're done.
        defer {
            nm_nifti_free(volumePtr)
        }

        // Extract dimensions and basic metadata
        let ndim       = Int(vol.ndim)
        let width      = Int(vol.width)
        let height     = Int(vol.height)
        let depth      = max(Int(vol.depth), 1)
        let timepoints = max(Int(vol.timepoints), 1)
        let voxelCount = Int(vol.voxelCount)
        let isNifti2   = (vol.isNifti2 != 0)

        guard width > 0, height > 0, depth > 0, timepoints > 0, voxelCount > 0 else {
            throw NIfTILoaderError.invalidVolume
        }

        guard let dataPtr = vol.data else {
            throw NIfTILoaderError.missingData
        }

        // Consistency check between voxelCount and dims
        let expectedCount = width * height * depth * timepoints
        if expectedCount != voxelCount {
            print("[NIfTILoader] Warning: voxelCount (\(voxelCount)) != width*height*depth*timepoints (\(expectedCount)). Using raw buffer as-is.")
        }

        // Debug / smoke-test logging
        print("""
        [NIfTILoader] Loaded NIfTI:
          path       = \(path)
          ndim       = \(ndim)
          size       = \(width) x \(height) x \(depth)
          timepoints = \(timepoints)
          voxelCount = \(voxelCount)
          spacing    = (\(vol.spacingX), \(vol.spacingY), \(vol.spacingZ))
          isNifti2   = \(isNifti2)
        """)

        // Copy C float* into Swift [Float]
        let buffer = UnsafeBufferPointer(start: dataPtr, count: voxelCount)
        let voxels = Array(buffer)

        // Build CIImageVolume using your existing model type.
        // Adjust the initializer if CIImageVolume has a different signature.
        return CIImageVolume(
            width: width,
            height: height,
            depth: depth,
            spacing: (vol.spacingX, vol.spacingY, vol.spacingZ),
            voxels: voxels
        )
    }
}
