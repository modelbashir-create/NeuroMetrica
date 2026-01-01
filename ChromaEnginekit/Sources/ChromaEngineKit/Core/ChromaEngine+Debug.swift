//
//  ChromaEngine+Debug.swift
//  ChromaEngineKit
//

import Foundation

// MARK: - Debug

extension ChromaEngine {

    func logRenderPath(_ path: String, reason: String?) {
        if let reason {
            NSLog("ChromaEngine: render path=%@ (%@)", path, reason)
        } else {
            NSLog("ChromaEngine: render path=%@", path)
        }
#if DEBUG
        ChromaEngine.renderLogQueue.sync {
            ChromaEngine.lastRenderPath = path
            ChromaEngine.lastFallbackReason = reason
        }
#endif
    }

    func logGeometryValidationIfNeeded(metadata: CIMetadata, volume: CImageVolume) {
#if DEBUG
        guard let validation = metadata.geometryValidation else { return }
        let key = ObjectIdentifier(volume.voxelData as NSData)
        let shouldLog: Bool = ChromaEngine.geometryLogQueue.sync {
            if ChromaEngine.geometryValidationLogged.contains(key) {
                return false
            }
            ChromaEngine.geometryValidationLogged.insert(key)
            return true
        }
        guard shouldLog else { return }

        var findings: [String] = []
        if validation.sliceOrder == "reversed" {
            findings.append("sliceOrder=reversed")
        } else if validation.sliceOrder == "inconsistent" {
            findings.append("sliceOrder=inconsistent")
        }
        if !validation.spacingUniform {
            findings.append("spacing=non_uniform")
        }
        if validation.leftHanded {
            findings.append("direction=left_handed")
        }
        guard !findings.isEmpty else { return }
        NSLog("ChromaEngine geometry validation: %@ (status=%@)",
              findings.joined(separator: ","),
              validation.validationStatus)
#endif
    }

    func debugCompareGPUOutput(
        gpuSlice: CIImage2D,
        cpuSlice: CIImage2D,
        volume: CImageVolume,
        orientation: SliceOrientation,
        index: Int,
        window: Float,
        level: Float
    ) {
        #if DEBUG
        guard shouldCompareGPUOutput() else { return }
        guard gpuSlice.componentType == .uint8,
              gpuSlice.componentsPerPixel == 1 else {
            NSLog("ChromaEngine: GPU compare skipped (unexpected slice format)")
            return
        }

        guard cpuSlice.width == gpuSlice.width,
              cpuSlice.height == gpuSlice.height else {
            NSLog("ChromaEngine: GPU compare skipped (dimension mismatch)")
            return
        }

        let samples = sampleCoordinates(
            width: gpuSlice.width,
            height: gpuSlice.height,
            seed: index ^ gpuSlice.width ^ gpuSlice.height
        )
        var mismatchCount = 0
        var maxDiff: Int = 0
        var logged = 0

        gpuSlice.data.withUnsafeBytes { gpuPtr in
            cpuSlice.data.withUnsafeBytes { cpuPtr in
                guard let gpuBase = gpuPtr.bindMemory(to: UInt8.self).baseAddress,
                      let cpuBase = cpuPtr.bindMemory(to: UInt8.self).baseAddress else { return }
                for (x, y) in samples {
                    let idx = y * gpuSlice.width + x
                    let gpuValue = Int(gpuBase[idx])
                    let cpuValue = Int(cpuBase[idx])
                    let diff = abs(gpuValue - cpuValue)
                    if diff > 1 {
                        mismatchCount += 1
                        maxDiff = max(maxDiff, diff)
                        if logged < 8 {
                            NSLog("ChromaEngine: GPU compare mismatch axis=%@ idx=%d voxelType=%@ WW/WL=%.3f/%.3f at (%d,%d) cpu=%d gpu=%d diff=%d",
                                  "\(orientation)", index, cpuSlice.componentType.rawValue, window, level, x, y, cpuValue, gpuValue, diff)
                            logged += 1
                        }
                    }
                }
            }
        }

        if mismatchCount > 0 {
            NSLog("ChromaEngine: GPU compare summary axis=%@ idx=%d mismatches=%d maxDiff=%d",
                  "\(orientation)", index, mismatchCount, maxDiff)
        }
        #endif
    }

    func debugCompareGPUVolumeOutput(
        gpuImage: CIImage2D,
        cpuImage: CIImage2D,
        orientation: SliceOrientation,
        window: Float,
        level: Float,
        step: Float
    ) {
#if DEBUG
        guard shouldCompareGPUOutput() else { return }
        guard gpuImage.componentType == .uint8,
              gpuImage.componentsPerPixel == 1 else {
            NSLog("ChromaEngine: GPU volume compare skipped (unexpected format)")
            return
        }

        guard cpuImage.width == gpuImage.width,
              cpuImage.height == gpuImage.height else {
            NSLog("ChromaEngine: GPU volume compare skipped (dimension mismatch)")
            return
        }

        let samples = sampleCoordinates(
            width: gpuImage.width,
            height: gpuImage.height,
            seed: gpuImage.width ^ gpuImage.height
        )
        var mismatchCount = 0
        var maxDiff: Int = 0
        var logged = 0

        gpuImage.data.withUnsafeBytes { gpuPtr in
            cpuImage.data.withUnsafeBytes { cpuPtr in
                guard let gpuBase = gpuPtr.bindMemory(to: UInt8.self).baseAddress,
                      let cpuBase = cpuPtr.bindMemory(to: UInt8.self).baseAddress else { return }
                for (x, y) in samples {
                    let idx = y * gpuImage.width + x
                    let gpuValue = Int(gpuBase[idx])
                    let cpuValue = Int(cpuBase[idx])
                    let diff = abs(gpuValue - cpuValue)
                    if diff > 1 {
                        mismatchCount += 1
                        maxDiff = max(maxDiff, diff)
                        if logged < 8 {
                            NSLog("ChromaEngine: GPU volume compare mismatch axis=%@ WW/WL=%.3f/%.3f step=%.2f at (%d,%d) cpu=%d gpu=%d diff=%d",
                                  "\(orientation)", window, level, step, x, y, cpuValue, gpuValue, diff)
                            logged += 1
                        }
                    }
                }
            }
        }

        if mismatchCount > 0 {
            NSLog("ChromaEngine: GPU volume compare summary axis=%@ mismatches=%d maxDiff=%d",
                  "\(orientation)", mismatchCount, maxDiff)
        }
#endif
    }

    func sampleCoordinates(width: Int, height: Int, seed: Int) -> [(Int, Int)] {
        let maxX = max(width - 1, 0)
        let maxY = max(height - 1, 0)
        let midX = width / 2
        let midY = height / 2
        var coords: [(Int, Int)] = [
            (0, 0),
            (maxX, 0),
            (0, maxY),
            (maxX, maxY),
            (midX, midY)
        ]
        coords.append(contentsOf: pseudoRandomCoordinates(width: width, height: height, seed: seed, count: 4))
        return coords
    }

    func shouldCompareGPUOutput() -> Bool {
        config.enableGPUDebugComparison
    }

    func pseudoRandomCoordinates(width: Int, height: Int, seed: Int, count: Int) -> [(Int, Int)] {
        var result: [(Int, Int)] = []
        var state = UInt64(bitPattern: Int64(seed))
        let maxX = max(width - 1, 0)
        let maxY = max(height - 1, 0)
        for _ in 0..<count {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            let x = Int(state & 0xFFFF) % (maxX + 1)
            let y = Int((state >> 16) & 0xFFFF) % (maxY + 1)
            result.append((x, y))
        }
        return result
    }
}
