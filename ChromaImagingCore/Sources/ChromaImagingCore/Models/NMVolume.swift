import Foundation

/// Core neutral volume type used across NeuroMetrica.
///
/// All engines (ITK, native Metal path, etc.) should produce and consume
/// this type. The UI and higher-level logic never see C++/ITK types directly.
public struct NMVolume: Sendable {
    /// Dimensions in voxels. `t` is for time / volume index; for most
    /// static clinical scans this will be 1.
    public var dimensions: (x: Int, y: Int, z: Int, t: Int)

    /// Physical spacing between voxels (in mm) along each axis.
    public var spacing: (x: Double, y: Double, z: Double)

    /// Physical origin (in mm) in patient / scanner space.
    public var origin: (x: Double, y: Double, z: Double)

    /// 3×3 direction cosines matrix in row-major order.
    /// Must contain exactly 9 elements.
    public var direction: [Double]

    /// Scalar type for this volume (int16, float32, etc.).
    public var scalarType: NMScalarType

    /// Raw voxel buffer. Layout and interpretation depends on `scalarType`.
    ///
    /// For now we assume:
    ///   - single component per voxel (no vector pixels),
    ///   - contiguous storage: (((t, z, y, x))).
    public var data: Data

    // MARK: Derived properties

    /// Total number of voxels (x * y * z * t).
    public var voxelCount: Int {
        max(0, dimensions.x)
        * max(0, dimensions.y)
        * max(0, dimensions.z)
        * max(1, dimensions.t)
    }

    /// Number of scalar components per voxel.
    /// We keep this as `1` for now; if we add RGB / vectors later
    /// this becomes part of the descriptor.
    public var componentsPerVoxel: Int { 1 }

    /// Expected number of bytes in `data` based on dimensions + scalarType.
    public var expectedDataLength: Int {
        voxelCount * componentsPerVoxel * scalarType.bytesPerComponent
    }

    // MARK: Init

    /// Designated initializer with optional consistency check.
    ///
    /// - Parameters:
    ///   - validateDataSize: when `true`, will throw if `data.count`
    ///     does not match the expected size from dimensions + scalarType.
    public init(
        dimensions: (x: Int, y: Int, z: Int, t: Int),
        spacing: (x: Double, y: Double, z: Double),
        origin: (x: Double, y: Double, z: Double),
        direction: [Double],
        scalarType: NMScalarType,
        data: Data,
        validateDataSize: Bool = true
    ) throws {
        precondition(direction.count == 9, "direction must be a 3×3 matrix (9 elements)")

        self.dimensions = dimensions
        self.spacing = spacing
        self.origin = origin
        self.direction = direction
        self.scalarType = scalarType
        self.data = data

        if validateDataSize {
            let expected = expectedDataLength
            if data.count != expected {
                throw NMImageIOError.inconsistentData(
                    expectedBytes: expected,
                    actualBytes: data.count
                )
            }
        }
    }
}
