//
//  DummyStudyBrowser.swift
//  NeuroMetrica
//
//  Created by Mohamed Elbashir on 11/12/25.
//


import Foundation
import CoreGraphics

// MARK: - Dummy StudyBrowser

public final class DummyStudyBrowser: StudyBrowser {
    private var cachedStudy: Study?

    public init() {}

    public func loadDemoStudy() throws -> Study {
        if let s = cachedStudy { return s }

        // Build a simple synthetic gradient volume for testing
        let size = SIMD3<Int>(128, 128, 64)  // width, height, depth
        var voxels = [Int16]()
        voxels.reserveCapacity(size.x * size.y * size.z)

        for z in 0..<size.z {
            for y in 0..<size.y {
                for x in 0..<size.x {
                    let value = Int16((x + y + z) % 256)
                    voxels.append(value)
                }
            }
        }

        let volume = Volume3D(
            size: size,
            spacing: SIMD3<Float>(0.5, 0.5, 1.0),
            voxels: voxels
        )

        let series = Series(
            id: UUID(),
            description: "Demo CT Head",
            modality: "CT",
            bodyPart: "HEAD",
            volumes: [volume]
        )

        let summary = StudySummary(
            id: UUID(),
            patientName: "Demo Patient",
            description: "Demo CT Head",
            date: Date(),
            modalitySummary: "CT"
        )

        let study = Study(id: summary.id, summary: summary, series: [series])
        cachedStudy = study
        return study
    }
}

// MARK: - CPU SliceGenerator (supports all orientations)

public final class CPUSliceGenerator: SliceGenerator {
    public init() {}

    public func makeSlice(
        from volume: Volume3D<Int16>,
        orientation: VolumeOrientation,
        index: Int,
        window: Float,
        level: Float
    ) -> CGImage? {
        switch orientation {
        case .axial:
            return makeAxialSlice(from: volume, index: index, window: window, level: level)
        case .coronal:
            return makeCoronalSlice(from: volume, index: index, window: window, level: level)
        case .sagittal:
            return makeSagittalSlice(from: volume, index: index, window: window, level: level)
        }
    }

    // Axial: x (width), y (height), fix z
    private func makeAxialSlice(
        from volume: Volume3D<Int16>,
        index: Int,
        window: Float,
        level: Float
    ) -> CGImage? {
        let w = volume.size.x
        let h = volume.size.y
        let d = volume.size.z
        let z = max(0, min(index, d - 1))

        var pixels = [UInt8](repeating: 0, count: w * h)
        let (minVal, maxVal) = wwWlRange(window: window, level: level)

        for y in 0..<h {
            for x in 0..<w {
                let voxelIndex = (z * h + y) * w + x
                let raw = Float(volume.voxels[voxelIndex])
                pixels[y * w + x] = mapToByte(raw, minVal: minVal, maxVal: maxVal)
            }
        }

        return makeGrayImage(width: w, height: h, pixels: pixels)
    }

    // Coronal: x (width), z (height), fix y
    private func makeCoronalSlice(
        from volume: Volume3D<Int16>,
        index: Int,
        window: Float,
        level: Float
    ) -> CGImage? {
        let w = volume.size.x
        let h = volume.size.y
        let d = volume.size.z
        let yFixed = max(0, min(index, h - 1))

        var pixels = [UInt8](repeating: 0, count: w * d)
        let (minVal, maxVal) = wwWlRange(window: window, level: level)

        for z in 0..<d {
            for x in 0..<w {
                let voxelIndex = (z * h + yFixed) * w + x
                let raw = Float(volume.voxels[voxelIndex])
                pixels[z * w + x] = mapToByte(raw, minVal: minVal, maxVal: maxVal)
            }
        }

        return makeGrayImage(width: w, height: d, pixels: pixels)
    }

    // Sagittal: y (width), z (height), fix x
    private func makeSagittalSlice(
        from volume: Volume3D<Int16>,
        index: Int,
        window: Float,
        level: Float
    ) -> CGImage? {
        let w = volume.size.x
        let h = volume.size.y
        let d = volume.size.z
        let xFixed = max(0, min(index, w - 1))

        var pixels = [UInt8](repeating: 0, count: h * d)
        let (minVal, maxVal) = wwWlRange(window: window, level: level)

        for z in 0..<d {
            for y in 0..<h {
                let voxelIndex = (z * h + y) * w + xFixed
                let raw = Float(volume.voxels[voxelIndex])
                pixels[z * h + y] = mapToByte(raw, minVal: minVal, maxVal: maxVal)
            }
        }

        return makeGrayImage(width: h, height: d, pixels: pixels)
    }

    // MARK: - Helpers

    private func wwWlRange(window: Float, level: Float) -> (Float, Float) {
        let minVal = level - window / 2
        let maxVal = level + window / 2
        return (minVal, maxVal)
    }

    private func mapToByte(_ value: Float, minVal: Float, maxVal: Float) -> UInt8 {
        let scaled = (value - minVal) / (maxVal - minVal) * 255.0
        let clamped = max(0, min(255, Int(scaled)))
        return UInt8(clamped)
    }

    private func makeGrayImage(width: Int, height: Int, pixels: [UInt8]) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: 0),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}