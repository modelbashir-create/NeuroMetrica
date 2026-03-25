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
    private let queueKey = DispatchSpecificKey<UInt8>()
    private let queueContext: UInt8 = 1
    private let renderer: MetalSliceRenderer?
    private var cache: [VolumeCacheKey: CachedVolume] = [:]
#if DEBUG
    private var debugForcedError: MetalSliceRendererError?
#endif

    init(renderer: MetalSliceRenderer? = MetalSliceRenderer()) {
        queue.setSpecific(key: queueKey, value: queueContext)
        self.renderer = renderer
    }

    func prepare(volume: CImageVolume) throws -> MetalPreparedVolume {
        try withRendererQueue {
            try prepareLocked(volume: volume)
        }
    }

    func renderSlice(request: MetalSliceRenderRequest) throws -> CIImage2D {
        try withRendererQueue {
#if DEBUG
            if let forced = debugForcedError {
                throw forced
            }
#endif
            let prepared = try prepareLocked(volume: request.volume)
            guard let renderer = renderer else {
                throw MetalSliceRendererError.metalUnavailable
            }
            return try renderer.renderSlice(preparedVolume: prepared, request: request)
        }
    }

    func renderVolume(request: MetalVolumeRenderRequest) throws -> CIImage2D {
        try withRendererQueue {
#if DEBUG
            if let forced = debugForcedError {
                throw forced
            }
#endif
            let prepared = try prepareLocked(volume: request.volume)
            guard let renderer = renderer else {
                throw MetalSliceRendererError.metalUnavailable
            }
            return try renderer.renderVolume(preparedVolume: prepared, request: request)
        }
    }

    func invalidate(volume: CImageVolume) {
        withRendererQueue {
            let key = makeKey(from: volume)
            cache.removeValue(forKey: key)
#if DEBUG
            NSLog("ChromaEngine GPU cache invalidated for volume=%@", key.dataIdentity.debugDescription)
#endif
        }
    }

    func invalidateAll() {
        withRendererQueue {
            cache.removeAll()
#if DEBUG
            NSLog("ChromaEngine GPU cache invalidated (all volumes)")
#endif
        }
    }

#if DEBUG
    func setDebugForcedError(_ error: MetalSliceRendererError?) {
        withRendererQueue {
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

    private func prepareLocked(volume: CImageVolume) throws -> MetalPreparedVolume {
        logPrepareDiagnostics(volume)
        let key = makeKey(from: volume)
        if let cached = cache[key] {
            cache[key] = CachedVolume(prepared: cached.prepared, lastUsed: Date())
            return cached.prepared
        }
        guard let renderer = renderer else {
            throw MetalSliceRendererError.metalUnavailable
        }
        let prepared = try renderer.prepare(volume: volume)
        cache[key] = CachedVolume(prepared: prepared, lastUsed: Date())
        return prepared
    }

    private func withRendererQueue<T>(_ body: () throws -> T) rethrows -> T {
        if DispatchQueue.getSpecific(key: queueKey) == queueContext {
            return try body()
        }
        return try queue.sync(execute: body)
    }
}
