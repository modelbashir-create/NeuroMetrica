import Foundation
import ChromaEngineKit

enum ImageDataStatus: String {
    case present = "present"
    case missing = "missing"
    case malformed = "malformed"
    case inconsistent = "inconsistent"
    case notApplicable = "n/a"
}

struct ImageDataChecklistEntry: Identifiable {
    let id = UUID()
    let label: String
    let tag: String?
    let status: ImageDataStatus
    let detail: String?
}

struct ImageDataRange: Equatable {
    let min: Double
    let max: Double
}

struct ImageDataSliceStats: Identifiable, Equatable {
    let id = UUID()
    let index: Int
    let range: ImageDataRange
}

struct ImageDataVolumeStats: Equatable {
    let range: ImageDataRange
    let isConstant: Bool
    let isZero: Bool
    let hasNaN: Bool
    let hasInf: Bool
}

struct ImageDataReport {
    let sourceFormat: CIMetadataSourceFormat
    let pixelData: [ImageDataChecklistEntry]
    let encoding: [ImageDataChecklistEntry]
    let scaling: [ImageDataChecklistEntry]
    let transferSyntax: [ImageDataChecklistEntry]
    let consistency: [ImageDataChecklistEntry]
    let geometry: [ImageDataChecklistEntry]
    let rendering: [ImageDataChecklistEntry]
    let volumeStats: ImageDataVolumeStats?
    let sliceStats: [ImageDataSliceStats]
}

@MainActor
enum ImageDataDiagnostics {

    static func report(for volume: CImageVolume, metadata: CIMetadata) -> ImageDataReport {
        let isDicom = metadata.sourceFormat == .dicom

        let pixelDataEntry = pixelDataPresenceEntry(volume: volume, isDicom: isDicom)
        let rowsColumnsEntry = rowsColumnsEntry(volume: volume, metadata: metadata, isDicom: isDicom)
        let sliceCountEntry = sliceCountEntry(volume: volume, metadata: metadata, isDicom: isDicom)

        let encodingEntries: [ImageDataChecklistEntry] = [
            bitsAllocatedEntry(volume: volume, metadata: metadata, isDicom: isDicom),
            bitsStoredEntry(metadata: metadata, isDicom: isDicom),
            highBitEntry(metadata: metadata, isDicom: isDicom),
            pixelRepresentationEntry(volume: volume, metadata: metadata, isDicom: isDicom)
        ]

        let scalingEntries: [ImageDataChecklistEntry] = [
            rescaleEntry(metadata: metadata, isDicom: isDicom)
        ]

        let transferEntries: [ImageDataChecklistEntry] = [
            transferSyntaxEntry(metadata: metadata, isDicom: isDicom)
        ]

        let consistencyEntries: [ImageDataChecklistEntry] = [
            pixelDataConsistencyEntry(metadata: metadata, isDicom: isDicom),
            geometryConsistencyEntry(metadata: metadata, isDicom: isDicom)
        ]

        let geometryEntries: [ImageDataChecklistEntry] = [
            pixelSpacingEntry(metadata: metadata, isDicom: isDicom),
            sliceSpacingEntry(volume: volume, metadata: metadata, isDicom: isDicom)
        ]

        let stats = computeStats(volume: volume)
        let renderingEntries: [ImageDataChecklistEntry] = [
            voxelRangeEntry(stats: stats),
            constantBufferEntry(stats: stats),
            nanInfEntry(stats: stats, isDicom: isDicom)
        ]

        return ImageDataReport(
            sourceFormat: metadata.sourceFormat,
            pixelData: [pixelDataEntry, rowsColumnsEntry, sliceCountEntry],
            encoding: encodingEntries,
            scaling: scalingEntries,
            transferSyntax: transferEntries,
            consistency: consistencyEntries,
            geometry: geometryEntries,
            rendering: renderingEntries,
            volumeStats: stats?.volume,
            sliceStats: stats?.slices ?? []
        )
    }

    static func logReport(_ report: ImageDataReport) {
        let entries = report.pixelData + report.encoding + report.scaling
            + report.transferSyntax + report.consistency + report.geometry + report.rendering
        let present = entries.filter { $0.status == .present }.count
        let missing = entries.filter { $0.status == .missing }.count
        let malformed = entries.filter { $0.status == .malformed }.count
        let inconsistent = entries.filter { $0.status == .inconsistent }.count
        let notApplicable = entries.filter { $0.status == .notApplicable }.count

        AppLogger.info("Image data checklist: present=\(present), missing=\(missing), malformed=\(malformed), inconsistent=\(inconsistent), n/a=\(notApplicable)")

        for entry in entries where entry.status == .missing || entry.status == .malformed || entry.status == .inconsistent {
            let tagSuffix = entry.tag.map { " [\($0)]" } ?? ""
            let detail = entry.detail ?? ""
            let message = "Image data \(entry.status.rawValue): \(entry.label)\(tagSuffix)\(detail.isEmpty ? "" : " — \(detail)")"
            AppLogger.info(message)
        }
    }

    // MARK: - Checklist entries

    private static func pixelDataPresenceEntry(volume: CImageVolume, isDicom: Bool) -> ImageDataChecklistEntry {
        guard isDicom else {
            return entry(label: "Pixel Data", tag: "7FE0,0010", status: .notApplicable, detail: nil)
        }

        let expected = volume.byteCount
        let actual = volume.voxelData.count
        if actual == 0 {
            return entry(label: "Pixel Data", tag: "7FE0,0010", status: .missing, detail: nil)
        }
        if actual < expected {
            return entry(label: "Pixel Data", tag: "7FE0,0010", status: .malformed, detail: "buffer too small (\(actual) < \(expected) bytes)")
        }
        let detail = actual > expected ? "buffer larger than expected (\(actual) > \(expected) bytes)" : nil
        return entry(label: "Pixel Data", tag: "7FE0,0010", status: .present, detail: detail)
    }

    private static func rowsColumnsEntry(volume: CImageVolume, metadata: CIMetadata, isDicom: Bool) -> ImageDataChecklistEntry {
        guard isDicom else {
            return entry(label: "Rows / Columns", tag: "0028,0010/0028,0011", status: .notApplicable, detail: nil)
        }
        guard let rows = metadata.rows, let columns = metadata.columns else {
            return entry(label: "Rows / Columns", tag: "0028,0010/0028,0011", status: .missing, detail: nil)
        }
        let matches = rows == volume.sizeY && columns == volume.sizeX
        let status: ImageDataStatus = matches ? .present : .inconsistent
        let detail = "rows=\(rows), cols=\(columns), decoded=\(volume.sizeY)x\(volume.sizeX)"
        return entry(label: "Rows / Columns", tag: "0028,0010/0028,0011", status: status, detail: detail)
    }

    private static func sliceCountEntry(volume: CImageVolume, metadata: CIMetadata, isDicom: Bool) -> ImageDataChecklistEntry {
        guard isDicom else {
            return entry(label: "Instance Count", tag: "0020,1209/0028,0008", status: .notApplicable, detail: nil)
        }
        let expected = metadata.numberOfInstances ?? metadata.numberOfFrames
        guard let expected, expected > 0 else {
            return entry(label: "Instance Count", tag: "0020,1209/0028,0008", status: .missing, detail: nil)
        }
        let matches = expected == volume.sizeZ
        let status: ImageDataStatus = matches ? .present : .inconsistent
        let detail = "expected=\(expected), decoded=\(volume.sizeZ)"
        return entry(label: "Instance Count", tag: "0020,1209/0028,0008", status: status, detail: detail)
    }

    private static func bitsAllocatedEntry(volume: CImageVolume, metadata: CIMetadata, isDicom: Bool) -> ImageDataChecklistEntry {
        guard isDicom else {
            return entry(label: "Bits Allocated", tag: "0028,0100", status: .notApplicable, detail: nil)
        }
        guard let bitsAllocated = metadata.bitsAllocated else {
            return entry(label: "Bits Allocated", tag: "0028,0100", status: .missing, detail: nil)
        }
        let expected = volume.bytesPerComponent * 8
        let status: ImageDataStatus = bitsAllocated == expected ? .present : .inconsistent
        let detail = "tag=\(bitsAllocated), decoded=\(expected)"
        return entry(label: "Bits Allocated", tag: "0028,0100", status: status, detail: detail)
    }

    private static func bitsStoredEntry(metadata: CIMetadata, isDicom: Bool) -> ImageDataChecklistEntry {
        guard isDicom else {
            return entry(label: "Bits Stored", tag: "0028,0101", status: .notApplicable, detail: nil)
        }
        guard let bitsStored = metadata.bitsStored else {
            return entry(label: "Bits Stored", tag: "0028,0101", status: .missing, detail: nil)
        }
        guard let bitsAllocated = metadata.bitsAllocated else {
            return entry(label: "Bits Stored", tag: "0028,0101", status: .present, detail: "value=\(bitsStored)")
        }
        let status: ImageDataStatus = bitsStored <= bitsAllocated ? .present : .malformed
        let detail = "stored=\(bitsStored), allocated=\(bitsAllocated)"
        return entry(label: "Bits Stored", tag: "0028,0101", status: status, detail: detail)
    }

    private static func highBitEntry(metadata: CIMetadata, isDicom: Bool) -> ImageDataChecklistEntry {
        guard isDicom else {
            return entry(label: "High Bit", tag: "0028,0102", status: .notApplicable, detail: nil)
        }
        guard let highBit = metadata.highBit else {
            return entry(label: "High Bit", tag: "0028,0102", status: .missing, detail: nil)
        }
        guard let bitsStored = metadata.bitsStored else {
            return entry(label: "High Bit", tag: "0028,0102", status: .present, detail: "value=\(highBit)")
        }
        let expected = max(bitsStored - 1, 0)
        let status: ImageDataStatus = highBit == expected ? .present : .inconsistent
        let detail = "highBit=\(highBit), expected=\(expected)"
        return entry(label: "High Bit", tag: "0028,0102", status: status, detail: detail)
    }

    private static func pixelRepresentationEntry(volume: CImageVolume, metadata: CIMetadata, isDicom: Bool) -> ImageDataChecklistEntry {
        guard isDicom else {
            return entry(label: "Pixel Representation", tag: "0028,0103", status: .notApplicable, detail: nil)
        }
        guard let pixelRepresentation = metadata.pixelRepresentation else {
            return entry(label: "Pixel Representation", tag: "0028,0103", status: .missing, detail: nil)
        }
        let isSigned = pixelRepresentation == 1
        let status: ImageDataStatus = isSigned == volume.isSigned ? .present : .inconsistent
        let detail = "tag=\(pixelRepresentation), decodedSigned=\(volume.isSigned ? 1 : 0)"
        return entry(label: "Pixel Representation", tag: "0028,0103", status: status, detail: detail)
    }

    private static func rescaleEntry(metadata: CIMetadata, isDicom: Bool) -> ImageDataChecklistEntry {
        guard isDicom else {
            return entry(label: "Rescale Slope / Intercept", tag: "0028,1053/0028,1052", status: .notApplicable, detail: nil)
        }
        guard let slope = metadata.rescaleSlope, let intercept = metadata.rescaleIntercept else {
            return entry(label: "Rescale Slope / Intercept", tag: "0028,1053/0028,1052", status: .missing, detail: nil)
        }
        guard slope.isFinite, intercept.isFinite, slope != 0 else {
            return entry(label: "Rescale Slope / Intercept", tag: "0028,1053/0028,1052", status: .malformed, detail: "slope=\(formatDouble(slope)), intercept=\(formatDouble(intercept))")
        }
        let detail = "slope=\(formatDouble(slope)), intercept=\(formatDouble(intercept))"
        return entry(label: "Rescale Slope / Intercept", tag: "0028,1053/0028,1052", status: .present, detail: detail)
    }

    private static func transferSyntaxEntry(metadata: CIMetadata, isDicom: Bool) -> ImageDataChecklistEntry {
        guard isDicom else {
            return entry(label: "Transfer Syntax", tag: "0002,0010", status: .notApplicable, detail: nil)
        }
        guard let uid = metadata.transferSyntaxUID, !uid.isEmpty else {
            return entry(label: "Transfer Syntax", tag: "0002,0010", status: .missing, detail: nil)
        }
        if let description = transferSyntaxDescription(uid: uid) {
            return entry(label: "Transfer Syntax", tag: "0002,0010", status: .present, detail: description)
        }
        return entry(label: "Transfer Syntax", tag: "0002,0010", status: .malformed, detail: "unknown UID \(uid)")
    }

    private static func pixelDataConsistencyEntry(metadata: CIMetadata, isDicom: Bool) -> ImageDataChecklistEntry {
        guard isDicom else {
            return entry(label: "Slice Encoding Consistency", tag: nil, status: .notApplicable, detail: nil)
        }
        guard let consistent = metadata.pixelDataConsistentAcrossSlices else {
            return entry(label: "Slice Encoding Consistency", tag: nil, status: .missing, detail: nil)
        }
        return entry(label: "Slice Encoding Consistency", tag: nil, status: consistent ? .present : .inconsistent, detail: nil)
    }

    private static func geometryConsistencyEntry(metadata: CIMetadata, isDicom: Bool) -> ImageDataChecklistEntry {
        guard isDicom else {
            return entry(label: "Slice Geometry Consistency", tag: nil, status: .notApplicable, detail: nil)
        }
        guard let consistent = metadata.geometryConsistentAcrossSlices else {
            return entry(label: "Slice Geometry Consistency", tag: nil, status: .missing, detail: nil)
        }
        return entry(label: "Slice Geometry Consistency", tag: nil, status: consistent ? .present : .inconsistent, detail: nil)
    }

    private static func pixelSpacingEntry(metadata: CIMetadata, isDicom: Bool) -> ImageDataChecklistEntry {
        guard isDicom else {
            return entry(label: "Pixel Spacing", tag: "0028,0030", status: .notApplicable, detail: nil)
        }
        guard let spacing = metadata.pixelSpacing else {
            return entry(label: "Pixel Spacing", tag: "0028,0030", status: .missing, detail: nil)
        }
        if spacing.row <= 0 || spacing.column <= 0 {
            return entry(label: "Pixel Spacing", tag: "0028,0030", status: .malformed, detail: "row=\(formatDouble(spacing.row)), col=\(formatDouble(spacing.column))")
        }
        let detail = "row=\(formatDouble(spacing.row)), col=\(formatDouble(spacing.column))"
        return entry(label: "Pixel Spacing", tag: "0028,0030", status: .present, detail: detail)
    }

    private static func sliceSpacingEntry(volume: CImageVolume, metadata: CIMetadata, isDicom: Bool) -> ImageDataChecklistEntry {
        guard isDicom else {
            return entry(label: "Slice Thickness / Spacing", tag: "0018,0050/0018,0088", status: .notApplicable, detail: nil)
        }
        let thickness = metadata.sliceThickness
        let spacing = metadata.spacingBetweenSlices
        if thickness == nil && spacing == nil {
            return entry(label: "Slice Thickness / Spacing", tag: "0018,0050/0018,0088", status: .missing, detail: nil)
        }

        let epsilon = 1e-3
        var details: [String] = []
        var status: ImageDataStatus = .present
        if let thickness {
            details.append("thickness=\(formatDouble(thickness))")
            if thickness <= 0 {
                status = .malformed
            }
        }
        if let spacing {
            details.append("spacing=\(formatDouble(spacing))")
            if spacing <= 0 {
                status = .malformed
            }
            if abs(spacing - volume.spacingZ) > epsilon {
                status = .inconsistent
            }
        }
        if let thickness, let spacing, abs(thickness - spacing) > epsilon {
            status = .inconsistent
        }
        return entry(label: "Slice Thickness / Spacing", tag: "0018,0050/0018,0088", status: status, detail: details.joined(separator: ", "))
    }

    private static func voxelRangeEntry(stats: ImageDataStats?) -> ImageDataChecklistEntry {
        guard let stats else {
            return entry(label: "Voxel Range", tag: nil, status: .missing, detail: nil)
        }
        let detail = "min=\(formatDouble(stats.volume.range.min)), max=\(formatDouble(stats.volume.range.max))"
        return entry(label: "Voxel Range", tag: nil, status: .present, detail: detail)
    }

    private static func constantBufferEntry(stats: ImageDataStats?) -> ImageDataChecklistEntry {
        guard let stats else {
            return entry(label: "Constant Buffer", tag: nil, status: .missing, detail: nil)
        }
        let status: ImageDataStatus = stats.volume.isConstant ? .inconsistent : .present
        let detail = stats.volume.isConstant ? (stats.volume.isZero ? "all zero" : "all constant") : nil
        return entry(label: "Constant Buffer", tag: nil, status: status, detail: detail)
    }

    private static func nanInfEntry(stats: ImageDataStats?, isDicom: Bool) -> ImageDataChecklistEntry {
        guard let stats else {
            return entry(label: "NaN / Inf", tag: nil, status: isDicom ? .missing : .notApplicable, detail: nil)
        }
        if stats.volume.hasNaN || stats.volume.hasInf {
            let detail = "nan=\(stats.volume.hasNaN ? "yes" : "no"), inf=\(stats.volume.hasInf ? "yes" : "no")"
            return entry(label: "NaN / Inf", tag: nil, status: .malformed, detail: detail)
        }
        return entry(label: "NaN / Inf", tag: nil, status: .present, detail: nil)
    }

    private static func entry(label: String, tag: String?, status: ImageDataStatus, detail: String?) -> ImageDataChecklistEntry {
        ImageDataChecklistEntry(label: label, tag: tag, status: status, detail: detail)
    }

    private struct ImageDataStats {
        let volume: ImageDataVolumeStats
        let slices: [ImageDataSliceStats]
    }

    private static func computeStats(volume: CImageVolume) -> ImageDataStats? {
        guard volume.valueCount > 0, volume.voxelData.count > 0 else { return nil }
        switch volume.componentType {
        case .uint8:
            return computeStatsIntegers(volume: volume, type: UInt8.self)
        case .uint16:
            return computeStatsIntegers(volume: volume, type: UInt16.self)
        case .int16:
            return computeStatsIntegers(volume: volume, type: Int16.self)
        case .float32:
            return computeStatsFloats(volume: volume)
        }
    }

    private static func computeStatsIntegers<T: FixedWidthInteger>(
        volume: CImageVolume,
        type: T.Type
    ) -> ImageDataStats? {
        let expectedCount = volume.valueCount
        let valuesPerSlice = volume.sizeX * volume.sizeY * max(volume.componentsPerPixel, 1)
        guard expectedCount > 0, valuesPerSlice > 0 else { return nil }

        return volume.voxelData.withUnsafeBytes { rawBuffer in
            let buffer = rawBuffer.bindMemory(to: T.self)
            guard buffer.count >= expectedCount else { return nil }

            var sliceStats: [ImageDataSliceStats] = []
            var globalMin = Double(buffer[0])
            var globalMax = Double(buffer[0])

            for slice in 0..<volume.sizeZ {
                let start = slice * valuesPerSlice
                let end = start + valuesPerSlice
                guard start < buffer.count else { break }
                let cappedEnd = min(end, buffer.count)
                var sliceMin = Double(buffer[start])
                var sliceMax = Double(buffer[start])
                for i in start..<cappedEnd {
                    let value = Double(buffer[i])
                    if value < sliceMin { sliceMin = value }
                    if value > sliceMax { sliceMax = value }
                    if value < globalMin { globalMin = value }
                    if value > globalMax { globalMax = value }
                }
                sliceStats.append(
                    ImageDataSliceStats(
                        index: slice,
                        range: ImageDataRange(min: sliceMin, max: sliceMax)
                    )
                )
            }

            let isConstant = globalMin == globalMax
            let isZero = globalMin == 0 && globalMax == 0
            let volumeStats = ImageDataVolumeStats(
                range: ImageDataRange(min: globalMin, max: globalMax),
                isConstant: isConstant,
                isZero: isZero,
                hasNaN: false,
                hasInf: false
            )
            return ImageDataStats(volume: volumeStats, slices: sliceStats)
        }
    }

    private static func computeStatsFloats(volume: CImageVolume) -> ImageDataStats? {
        let expectedCount = volume.valueCount
        let valuesPerSlice = volume.sizeX * volume.sizeY * max(volume.componentsPerPixel, 1)
        guard expectedCount > 0, valuesPerSlice > 0 else { return nil }

        return volume.voxelData.withUnsafeBytes { rawBuffer in
            let buffer = rawBuffer.bindMemory(to: Float.self)
            guard buffer.count >= expectedCount else { return nil }

            var sliceStats: [ImageDataSliceStats] = []
            var hasNaN = false
            var hasInf = false
            var globalMin: Double = 0
            var globalMax: Double = 0
            var hasFiniteValue = false

            for slice in 0..<volume.sizeZ {
                let start = slice * valuesPerSlice
                let end = start + valuesPerSlice
                guard start < buffer.count else { break }
                let cappedEnd = min(end, buffer.count)

                var sliceMin: Double = 0
                var sliceMax: Double = 0
                var sliceHasFinite = false

                for i in start..<cappedEnd {
                    let value = buffer[i]
                    if value.isNaN {
                        hasNaN = true
                        continue
                    }
                    if value.isInfinite {
                        hasInf = true
                        continue
                    }
                    let doubleValue = Double(value)
                    if !hasFiniteValue {
                        globalMin = doubleValue
                        globalMax = doubleValue
                        hasFiniteValue = true
                    } else {
                        if doubleValue < globalMin { globalMin = doubleValue }
                        if doubleValue > globalMax { globalMax = doubleValue }
                    }
                    if !sliceHasFinite {
                        sliceMin = doubleValue
                        sliceMax = doubleValue
                        sliceHasFinite = true
                    } else {
                        if doubleValue < sliceMin { sliceMin = doubleValue }
                        if doubleValue > sliceMax { sliceMax = doubleValue }
                    }
                }

                if sliceHasFinite {
                    sliceStats.append(
                        ImageDataSliceStats(
                            index: slice,
                            range: ImageDataRange(min: sliceMin, max: sliceMax)
                        )
                    )
                }
            }

            guard hasFiniteValue else { return nil }

            let isConstant = globalMin == globalMax
            let isZero = globalMin == 0 && globalMax == 0
            let volumeStats = ImageDataVolumeStats(
                range: ImageDataRange(min: globalMin, max: globalMax),
                isConstant: isConstant,
                isZero: isZero,
                hasNaN: hasNaN,
                hasInf: hasInf
            )
            return ImageDataStats(volume: volumeStats, slices: sliceStats)
        }
    }

    private static func transferSyntaxDescription(uid: String) -> String? {
        switch uid {
        case "1.2.840.10008.1.2":
            return "Implicit VR Little Endian"
        case "1.2.840.10008.1.2.1":
            return "Explicit VR Little Endian"
        case "1.2.840.10008.1.2.2":
            return "Explicit VR Big Endian"
        case "1.2.840.10008.1.2.1.99":
            return "Deflated Explicit VR Little Endian"
        case "1.2.840.10008.1.2.4.50":
            return "JPEG Baseline"
        case "1.2.840.10008.1.2.4.51":
            return "JPEG Extended"
        case "1.2.840.10008.1.2.4.57":
            return "JPEG Lossless"
        case "1.2.840.10008.1.2.4.70":
            return "JPEG Lossless (SV1)"
        case "1.2.840.10008.1.2.4.80":
            return "JPEG-LS Lossless"
        case "1.2.840.10008.1.2.4.81":
            return "JPEG-LS Near-lossless"
        case "1.2.840.10008.1.2.4.90":
            return "JPEG 2000 Lossless"
        case "1.2.840.10008.1.2.4.91":
            return "JPEG 2000"
        case "1.2.840.10008.1.2.4.92":
            return "JPEG 2000 Multi-component"
        case "1.2.840.10008.1.2.4.93":
            return "JPEG 2000 Multi-component Lossless"
        case "1.2.840.10008.1.2.5":
            return "RLE Lossless"
        default:
            return nil
        }
    }

    private static func formatDouble(_ value: Double) -> String {
        var text = String(format: "%.4f", value)
        while text.contains(".") && text.last == "0" {
            text.removeLast()
        }
        if text.last == "." {
            text.removeLast()
        }
        return text
    }
}
