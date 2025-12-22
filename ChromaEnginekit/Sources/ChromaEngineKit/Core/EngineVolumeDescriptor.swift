import Foundation

/// Engine-level volume descriptor that includes metadata alongside the volume.
public struct EngineVolumeDescriptor: Sendable, Equatable {
    public let volume: CImageVolume
    public let metadata: CIMetadata

    public init(volume: CImageVolume, metadata: CIMetadata) {
        self.volume = volume
        self.metadata = metadata
    }
}
