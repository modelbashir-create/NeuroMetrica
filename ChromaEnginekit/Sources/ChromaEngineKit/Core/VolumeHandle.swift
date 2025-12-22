import Foundation

/// Opaque handle for a loaded volume.
///
/// The app keeps this identifier instead of holding engine buffers.
public struct VolumeHandle: Hashable, Sendable, Codable {
    public let id: UUID

    public init(id: UUID = UUID()) {
        self.id = id
    }
}
