import Foundation

/// Engine-level GPU slice rendering service.
///
/// Policy:
/// - Native orientation is preserved (no canonical reorientation).
/// - GPU must interpret spacing/origin/direction exactly as CPU does.
/// - CPU remains the correctness reference implementation.
final class MetalSliceRenderService {
    private struct VolumeCacheKey: Hashable {
        let dataIdentity: ObjectIdentifier
        let sizeX: Int
        let sizeY: Int
        let sizeZ: Int
    }

    private struct CachedVolume {
        let prepared: MetalPreparedVolume
        let lastUsed: Date
    }

    private let queue = DispatchQueue(label: "ChromaEngine.GPUSliceRenderQueue")
    private let renderer: MetalSliceRenderer?
    private var cache: [VolumeCacheKey: CachedVolume] = [:]
#if DEBUG
    private var debugForcedError: MetalSliceRendererError?
#endif

    init(renderer: MetalSliceRenderer? = MetalSliceRenderer()) {
        self.renderer = renderer
    }

    func prepare(volume: CImageVolume) throws -> MetalPreparedVolume {
        try queue.sync {
            logPrepareDiagnostics(volume)
            let key = makeKey(from: volume)
            if let cached = cache[key] {
                return cached.prepared
            }
            guard let renderer = renderer else {
                throw MetalSliceRendererError.metalUnavailable
            }
            let prepared = try renderer.prepare(volume: volume)
            cache[key] = CachedVolume(prepared: prepared, lastUsed: Date())
            return prepared
        }
    }

    func renderSlice(request: MetalSliceRenderRequest) throws -> CIImage2D {
        try queue.sync {
#if DEBUG
            if let forced = debugForcedError {
                throw forced
            }
#endif
            let prepared = try prepare(volume: request.volume)
            guard let renderer = renderer else {
                throw MetalSliceRendererError.metalUnavailable
            }
            return try renderer.renderSlice(preparedVolume: prepared, request: request)
        }
    }

    func renderVolume(request: MetalVolumeRenderRequest) throws -> CIImage2D {
        try queue.sync {
#if DEBUG
            if let forced = debugForcedError {
                throw forced
            }
#endif
            let prepared = try prepare(volume: request.volume)
            guard let renderer = renderer else {
                throw MetalSliceRendererError.metalUnavailable
            }
            return try renderer.renderVolume(preparedVolume: prepared, request: request)
        }
    }

    func invalidate(volume: CImageVolume) {
        queue.sync {
            let key = makeKey(from: volume)
            cache.removeValue(forKey: key)
#if DEBUG
            NSLog("ChromaEngine GPU cache invalidated for volume=%@", key.dataIdentity.debugDescription)
#endif
        }
    }

    func invalidateAll() {
        queue.sync {
            cache.removeAll()
#if DEBUG
            NSLog("ChromaEngine GPU cache invalidated (all volumes)")
#endif
        }
    }

#if DEBUG
    func setDebugForcedError(_ error: MetalSliceRendererError?) {
        queue.sync {
            debugForcedError = error
        }
    }
#endif

    private func makeKey(from volume: CImageVolume) -> VolumeCacheKey {
        let dataIdentity = ObjectIdentifier(volume.voxelData as NSData)
        return VolumeCacheKey(
            dataIdentity: dataIdentity,
            sizeX: volume.sizeX,
            sizeY: volume.sizeY,
            sizeZ: volume.sizeZ
        )
    }

    private func logPrepareDiagnostics(_ volume: CImageVolume) {
        let expectedBytes = volume.valueCount * volume.bytesPerComponent
        let dataType = "\(volume.componentType) \(volume.bytesPerComponent * 8)-bit"
        let dims = "\(volume.sizeX)x\(volume.sizeY)x\(volume.sizeZ)x\(volume.sizeT)"
        let strideAssumptions = "x-fastest,y,z,t,component; expectedBytes=\(expectedBytes)"
        NSLog("ChromaEngine GPU prepare: voxels=%d type=%@ dims=%@ stride=%@",
              volume.valueCount, dataType, dims, strideAssumptions)
    }
}
