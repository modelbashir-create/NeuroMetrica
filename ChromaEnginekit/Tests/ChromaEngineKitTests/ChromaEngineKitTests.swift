import XCTest
import simd
@testable import ChromaEngineKit
import ChromaImagingCore

final class ChromaEngineKitTests: XCTestCase {

    func testGPUDisabledUsesCPUPath() throws {
        let engine = ChromaEngine(config: ChromaEngineConfig(useGPUSliceRendering: false))
        let volume = makeVolume(componentsPerPixel: 1)
        let slice = try engine.makeSlice2D(from: volume, orientation: .axial, index: 0, window: 100, level: 50)
        XCTAssertEqual(slice.componentType, .uint8)
        XCTAssertEqual(slice.componentsPerPixel, 1)
        XCTAssertEqual(slice.bytesPerRow, slice.width)
        #if DEBUG
        XCTAssertEqual(ChromaEngine.getLastRenderPath(), "CPU")
        XCTAssertEqual(ChromaEngine.getLastFallbackReason(), "gpu_disabled")
        #endif
    }

    func testUnsupportedVoxelTypeFallsBackToCPU() throws {
        let engine = ChromaEngine(config: ChromaEngineConfig(useGPUSliceRendering: true))
        let volume = makeVolume(componentsPerPixel: 1)
        #if DEBUG
        ChromaEngine.setGPUDebugForcedError(.unsupportedComponentsPerPixel)
        defer { ChromaEngine.setGPUDebugForcedError(nil) }
        #endif
        let slice = try engine.makeSlice2D(from: volume, orientation: .axial, index: 0, window: 100, level: 50)
        XCTAssertEqual(slice.componentType, .uint8)
        #if DEBUG
        XCTAssertEqual(ChromaEngine.getLastRenderPath(), "CPU")
        XCTAssertEqual(ChromaEngine.getLastFallbackReason(), "gpu_fallback:unsupported_components_per_pixel")
        #endif
    }

    func testDebugComparisonDoesNotCrash() throws {
        let engine = ChromaEngine(config: ChromaEngineConfig(useGPUSliceRendering: true, enableGPUDebugComparison: true))
        let volume = makeVolume(componentsPerPixel: 1)
        #if DEBUG
        ChromaEngine.setGPUDebugForcedError(.pipelineStateCreationFailed)
        defer { ChromaEngine.setGPUDebugForcedError(nil) }
        #endif
        let slice = try engine.makeSlice2D(from: volume, orientation: .axial, index: 0, window: 100, level: 50)
        XCTAssertEqual(slice.componentType, .uint8)
    }

    func testSeriesCandidateMetadataParsing() throws {
        let engine = ChromaEngine(config: ChromaEngineConfig())
        let json = """
        {
          "_seriesCandidates":[
            {
              "candidateId":"group:a",
              "sliceCount":10,
              "groupingKeys":["0020|0037","0020|0032"],
              "orderingMethod":"ipp_iop"
            },
            {
              "candidateId":"group:b",
              "sliceCount":8,
              "groupingKeys":["0020|0037"],
              "rejectionReason":"smaller_stack"
            }
          ],
          "_selectedSeriesCandidateId":"group:a",
          "_seriesSelectionReason":"largest_group_by_slice_count",
          "_selectedSeriesCandidateInfo":{
            "candidateId":"group:a",
            "sliceCount":10,
            "orderingMethod":"ipp_iop",
            "groupingKeysUsed":["0020|0037","0020|0032"],
            "fallbackUsed":false,
            "selectionReason":"largest_group_by_slice_count"
          }
        }
        """

        let result = engine.parseSeriesDiagnostics(from: json)
        XCTAssertEqual(result.candidates?.count, 2)
        XCTAssertEqual(result.selectedCandidateId, "group:a")
        XCTAssertEqual(result.selectionReason, "largest_group_by_slice_count")
        XCTAssertEqual(result.candidates?.first?.orderingMethod, "ipp_iop")
        XCTAssertEqual(result.candidates?[1].rejectionReason, "smaller_stack")
        XCTAssertEqual(result.selectionInfo?.candidateId, "group:a")
        XCTAssertEqual(result.selectionInfo?.fallbackUsed, false)
    }

    func testDicomImportInspectionParsing() throws {
        let engine = ChromaEngine(config: ChromaEngineConfig())
        let json = """
        {
          "_seriesDiagnostics":[
            {
              "seriesInstanceUID":"series-1",
              "fileCount":24,
              "studyDescription":"Knee",
              "seriesDescription":"AX PD",
              "modality":"MR",
              "seriesNumber":"4"
            }
          ],
          "_subseriesDiagnostics":[
            {
              "seriesInstanceUID":"series-1",
              "subseriesKey":"stack-a",
              "fileCount":24,
              "confidence":5,
              "orientationConsistent":true,
              "spacingUniform":true,
              "reasons":[]
            }
          ],
          "_selectedSeriesInfo":{
            "seriesInstanceUID":"series-1",
            "subseriesKey":"stack-a",
            "confidence":5
          },
          "_inspectionSelectionPolicy":"highest_confidence_then_file_count_then_uid"
        }
        """

        let inspection = engine.parseDicomImportInspection(from: json)

        XCTAssertNotNil(inspection)
        XCTAssertEqual(inspection?.series.count, 1)
        XCTAssertEqual(inspection?.series.first?.seriesDescription, "AX PD")
        XCTAssertEqual(inspection?.series.first?.studyDescription, "Knee")
        XCTAssertEqual(inspection?.subseries.first?.subseriesKey, "stack-a")
        XCTAssertEqual(inspection?.selectedSeriesInfo?.seriesInstanceUID, "series-1")
        XCTAssertEqual(inspection?.selectionPolicy, "highest_confidence_then_file_count_then_uid")
    }

    func testGeometryValidationParsing() throws {
        let engine = ChromaEngine(config: ChromaEngineConfig())
        let json = """
        {
          "_geometryValidation":{
            "sliceOrder":"reversed",
            "spacing":{
              "uniform":false,
              "min":0.8,
              "max":1.2
            },
            "direction":{
              "orthonormal":true,
              "determinant":-1.0,
              "leftHanded":true
            },
            "usedDefaults":true,
            "validationStatus":"warning"
          }
        }
        """

        let validation = engine.parseGeometryValidation(from: json)
        XCTAssertNotNil(validation)
        XCTAssertEqual(validation?.sliceOrder, "reversed")
        XCTAssertEqual(validation?.spacingUniform, false)
        XCTAssertEqual(validation?.spacingMin, 0.8)
        XCTAssertEqual(validation?.spacingMax, 1.2)
        XCTAssertEqual(validation?.leftHanded, true)
        XCTAssertEqual(validation?.validationStatus, "warning")
    }

    func testBuildMetadataSupportsLowercaseDicomTagKeys() {
        let descriptor = ITKImageDescriptor(
            dimension: 3,
            size: [1, 1, 1],
            spacing: [1, 1, 1],
            origin: [0, 0, 0],
            direction: [
                1, 0, 0,
                0, 1, 0,
                0, 0, 1
            ],
            pixelType: .scalar,
            componentsPerPixel: 1,
            valueCount: 1,
            componentBytes: 2,
            isSigned: true,
            bufferPointer: nil,
            metadataJSON: """
            {
              "_orientationConsistent": true
            }
            """,
            metadata: [
                "0008,0060": .string("MR"),
                "0008,1030": .string("Knee (R)"),
                "0008,103e": .string("AX.  FSE PD"),
                "0010,0010": .string("Anonymized"),
                "0020,000d": .string("study-uid"),
                "0020,000e": .string("series-uid"),
                "0020,0011": .number(5),
                "_orientationConsistent": .boolean(true)
            ]
        )

        let engine = ChromaEngine(config: ChromaEngineConfig())
        let metadata = engine.buildMetadata(
            from: descriptor,
            sourceFormat: .dicom,
            sourceDescription: nil
        )

        XCTAssertEqual(metadata.modality, "MR")
        XCTAssertEqual(metadata.studyDescription, "Knee (R)")
        XCTAssertEqual(metadata.seriesDescription, "AX.  FSE PD")
        XCTAssertEqual(metadata.patientName, "Anonymized")
        XCTAssertEqual(metadata.studyInstanceUID, "study-uid")
        XCTAssertEqual(metadata.seriesInstanceUID, "series-uid")
        XCTAssertEqual(metadata.seriesNumber, 5)
        XCTAssertEqual(metadata.orientationConsistent, true)
    }

    func testVolumeRenderFallsBackToCPU() throws {
        let engine = ChromaEngine(config: ChromaEngineConfig(useGPUSliceRendering: true))
        let volume = makeVolume(componentsPerPixel: 1)
        #if DEBUG
        ChromaEngine.setGPUDebugForcedError(.pipelineStateCreationFailed)
        defer { ChromaEngine.setGPUDebugForcedError(nil) }
        #endif
        let image = try engine.renderVolume2D(from: volume, orientation: .axial, window: 100, level: 50)
        XCTAssertEqual(image.width, volume.sizeX)
        XCTAssertEqual(image.height, volume.sizeY)
        XCTAssertEqual(image.componentType, .uint8)
        #if DEBUG
        XCTAssertEqual(ChromaEngine.getLastRenderPath(), "CPU")
        #endif
    }

    func testVolumeRenderDebugComparisonDoesNotCrash() throws {
        let engine = ChromaEngine(config: ChromaEngineConfig(useGPUSliceRendering: true, enableGPUDebugComparison: true))
        let volume = makeVolume(componentsPerPixel: 1)
        #if DEBUG
        ChromaEngine.setGPUDebugForcedError(.pipelineStateCreationFailed)
        defer { ChromaEngine.setGPUDebugForcedError(nil) }
        #endif
        let image = try engine.renderVolume2D(from: volume, orientation: .axial, window: 100, level: 50)
        XCTAssertEqual(image.componentType, .uint8)
    }

    func testCPUForcedBackendDisablesGPU() throws {
        let engine = ChromaEngine(config: ChromaEngineConfig(renderingBackend: .cpu))
        let volume = makeVolume(componentsPerPixel: 1)
        #if DEBUG
        ChromaEngine.setGPUDebugForcedError(.pipelineStateCreationFailed)
        defer { ChromaEngine.setGPUDebugForcedError(nil) }
        #endif
        _ = try engine.makeSlice2D(from: volume, orientation: .axial, index: 0, window: 100, level: 50)
        #if DEBUG
        XCTAssertEqual(ChromaEngine.getLastRenderPath(), "CPU")
        XCTAssertEqual(ChromaEngine.getLastFallbackReason(), "gpu_disabled")
        #endif
    }

    func testGPUForcedBackendFallsBackSafely() throws {
        let engine = ChromaEngine(config: ChromaEngineConfig(renderingBackend: .gpu))
        let volume = makeVolume(componentsPerPixel: 1)
        #if DEBUG
        ChromaEngine.setGPUDebugForcedError(.pipelineStateCreationFailed)
        defer { ChromaEngine.setGPUDebugForcedError(nil) }
        #endif
        _ = try engine.makeSlice2D(from: volume, orientation: .axial, index: 0, window: 100, level: 50)
        #if DEBUG
        XCTAssertEqual(ChromaEngine.getLastRenderPath(), "CPU")
        XCTAssertTrue((ChromaEngine.getLastFallbackReason() ?? "").hasPrefix("gpu_fallback:"))
        #endif
    }

    func testAutomaticBackendAttemptsGPU() throws {
        let engine = ChromaEngine(config: ChromaEngineConfig(renderingBackend: .automatic))
        let volume = makeVolume(componentsPerPixel: 1)
        #if DEBUG
        ChromaEngine.setGPUDebugForcedError(.pipelineStateCreationFailed)
        defer { ChromaEngine.setGPUDebugForcedError(nil) }
        #endif
        _ = try engine.makeSlice2D(from: volume, orientation: .axial, index: 0, window: 100, level: 50)
        #if DEBUG
        XCTAssertEqual(ChromaEngine.getLastRenderPath(), "CPU")
        XCTAssertTrue((ChromaEngine.getLastFallbackReason() ?? "").hasPrefix("gpu_fallback:"))
        #endif
    }

    func testPatientSpaceRescaleAndWindowLevel() throws {
        let engine = ChromaEngine()
        let volume = makeVolume(
            values: [0, 10, 20, 30],
            sizeX: 2,
            sizeY: 2,
            sizeZ: 1
        )

        let slice = try engine.makeSlicePatientSpace(
            from: volume,
            orientation: .axial,
            index: 0,
            window: 40,
            level: 30,
            rescaleSlope: 2.0,
            rescaleIntercept: 10.0
        )

        XCTAssertEqual(slice.width, 2)
        XCTAssertEqual(slice.height, 2)
        XCTAssertEqual(slice.orientation, .axial)
        XCTAssertEqual([UInt8](slice.data), [0, 127, 255, 255])
    }

    func testPatientSpaceInterpolationModes() throws {
        let engine = ChromaEngine()
        let volume = makeVolume(
            values: [0, 100, 0, 100, 0, 100, 0, 100],
            sizeX: 2,
            sizeY: 2,
            sizeZ: 2
        )
        let plane = PatientPlane(
            origin: SIMD3<Double>(0.5, 0.0, 0.0),
            axisU: SIMD3<Double>(1.0, 0.0, 0.0),
            axisV: SIMD3<Double>(0.0, 1.0, 0.0),
            spacingU: 1.0,
            spacingV: 1.0,
            width: 1,
            height: 1,
            orientationHint: .axial,
            sliceIndexHint: 0
        )

        let linear = try engine.makeSliceMPRInternal(
            volume: volume,
            plane: plane,
            window: 100,
            level: 50,
            rescaleSlope: 1.0,
            rescaleIntercept: 0.0,
            interpolation: .linear
        )
        let nearest = try engine.makeSliceMPRInternal(
            volume: volume,
            plane: plane,
            window: 100,
            level: 50,
            rescaleSlope: 1.0,
            rescaleIntercept: 0.0,
            interpolation: .nearest
        )

        XCTAssertEqual([UInt8](linear.data), [127])
        XCTAssertEqual([UInt8](nearest.data), [255])
    }

    func testPatientSpaceOrientationDimensions() throws {
        let engine = ChromaEngine()
        let volume = makeVolume(values: Array(repeating: 0, count: 3 * 4 * 5), sizeX: 3, sizeY: 4, sizeZ: 5)

        let slice = try engine.makeSlicePatientSpace(
            from: volume,
            orientation: .coronal,
            index: 2,
            window: 100,
            level: 50
        )

        XCTAssertEqual(slice.width, 3)
        XCTAssertEqual(slice.height, 5)
        XCTAssertEqual(slice.orientation, .coronal)
        XCTAssertEqual(slice.sliceIndex, 2)
    }

    func testGPUPatientSpaceMatchesCPU() throws {
        #if canImport(Metal)
        guard ProcessInfo.processInfo.environment["NEUROMETRICA_ENABLE_GPU_TESTS"] == "1" else {
            throw XCTSkip("Set NEUROMETRICA_ENABLE_GPU_TESTS=1 to run Metal parity tests.")
        }
        guard let renderer = MetalSliceRenderer() else {
            throw XCTSkip("Metal not available")
        }
        let engine = ChromaEngine()
        let volume = makeVolume(
            values: makeRampValues(sizeX: 3, sizeY: 3, sizeZ: 3),
            sizeX: 3,
            sizeY: 3,
            sizeZ: 3,
            spacing: (1.0, 2.0, 3.0),
            direction: [
                0, 1, 0, 0,
                1, 0, 0, 0,
                0, 0, 1, 0,
                0, 0, 0, 1
            ],
            rescale: (2.0, 10.0)
        )

        let cpuSlice = try engine.makeSlicePatientSpace(
            from: volume,
            orientation: .coronal,
            index: 1,
            window: 200,
            level: 50,
            rescaleSlope: volume.rescaleSlope,
            rescaleIntercept: volume.rescaleIntercept,
            interpolation: .linear
        )

        let service = MetalSliceRenderService(renderer: renderer)
        let request = MetalSliceRenderRequest(
            volume: volume,
            orientation: .coronal,
            index: 1,
            window: 200,
            level: 50,
            rescaleSlope: Float(volume.rescaleSlope),
            rescaleIntercept: Float(volume.rescaleIntercept),
            interpolation: .linear
        )
        let gpuSlice = try service.renderSlice(request: request)

        assertSlicesEqual(gpuSlice, cpuSlice, tolerance: 1)
        #else
        throw XCTSkip("Metal not available")
        #endif
    }

    func testGPUNearestMatchesCPU() throws {
        #if canImport(Metal)
        guard ProcessInfo.processInfo.environment["NEUROMETRICA_ENABLE_GPU_TESTS"] == "1" else {
            throw XCTSkip("Set NEUROMETRICA_ENABLE_GPU_TESTS=1 to run Metal parity tests.")
        }
        guard let renderer = MetalSliceRenderer() else {
            throw XCTSkip("Metal not available")
        }
        let engine = ChromaEngine()
        let volume = makeVolume(
            values: makeRampValues(sizeX: 3, sizeY: 3, sizeZ: 3),
            sizeX: 3,
            sizeY: 3,
            sizeZ: 3,
            spacing: (1.0, 1.0, 1.0),
            direction: [
                1, 0, 0, 0,
                0, 1, 0, 0,
                0, 0, 1, 0,
                0, 0, 0, 1
            ],
            rescale: (1.0, 0.0)
        )

        let cpuSlice = try engine.makeSlicePatientSpace(
            from: volume,
            orientation: .sagittal,
            index: 1,
            window: 150,
            level: 50,
            rescaleSlope: volume.rescaleSlope,
            rescaleIntercept: volume.rescaleIntercept,
            interpolation: .nearest
        )

        let service = MetalSliceRenderService(renderer: renderer)
        let request = MetalSliceRenderRequest(
            volume: volume,
            orientation: .sagittal,
            index: 1,
            window: 150,
            level: 50,
            rescaleSlope: Float(volume.rescaleSlope),
            rescaleIntercept: Float(volume.rescaleIntercept),
            interpolation: .nearest
        )
        let gpuSlice = try service.renderSlice(request: request)

        assertSlicesEqual(gpuSlice, cpuSlice, tolerance: 1)
        #else
        throw XCTSkip("Metal not available")
        #endif
    }

    private func makeVolume(componentsPerPixel: Int) -> CImageVolume {
        let size = 4
        let bytesPerComponent = 2
        let componentType: CIPixelComponentType = .uint16
        let voxelCount = size * size * size
        let valueCount = voxelCount * componentsPerPixel
        let byteCount = valueCount * bytesPerComponent
        let data = Data(count: byteCount)

        return CImageVolume(
            dimension: 3,
            sizeX: size,
            sizeY: size,
            sizeZ: size,
            sizeT: 1,
            spacingX: 1.0,
            spacingY: 1.0,
            spacingZ: 1.0,
            spacingT: 1.0,
            originX: 0.0,
            originY: 0.0,
            originZ: 0.0,
            originT: 0.0,
            direction: [
                1, 0, 0, 0,
                0, 1, 0, 0,
                0, 0, 1, 0,
                0, 0, 0, 1
            ],
            componentType: componentType,
            componentsPerPixel: componentsPerPixel,
            bytesPerComponent: bytesPerComponent,
            isSigned: false,
            voxelData: data
        )
    }

    private func makeVolume(
        values: [UInt16],
        sizeX: Int,
        sizeY: Int,
        sizeZ: Int,
        spacing: (Double, Double, Double) = (1.0, 1.0, 1.0),
        direction: [Double] = [
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            0, 0, 0, 1
        ],
        origin: (Double, Double, Double) = (0.0, 0.0, 0.0),
        rescale: (Double, Double) = (1.0, 0.0)
    ) -> CImageVolume {
        let bytesPerComponent = 2
        var data = Data(count: values.count * bytesPerComponent)
        data.withUnsafeMutableBytes { outPtr in
            guard let base = outPtr.baseAddress else { return }
            var offset = 0
            for value in values {
                var le = value.littleEndian
                withUnsafeBytes(of: &le) { bytes in
                    guard let src = bytes.baseAddress else { return }
                    base.advanced(by: offset).copyMemory(from: src, byteCount: bytesPerComponent)
                }
                offset += bytesPerComponent
            }
        }

        return CImageVolume(
            dimension: 3,
            sizeX: sizeX,
            sizeY: sizeY,
            sizeZ: sizeZ,
            sizeT: 1,
            spacingX: spacing.0,
            spacingY: spacing.1,
            spacingZ: spacing.2,
            spacingT: 1.0,
            originX: origin.0,
            originY: origin.1,
            originZ: origin.2,
            originT: 0.0,
            direction: direction,
            componentType: .uint16,
            componentsPerPixel: 1,
            bytesPerComponent: bytesPerComponent,
            isSigned: false,
            rescaleSlope: rescale.0,
            rescaleIntercept: rescale.1,
            voxelData: data
        )
    }

    private func makeRampValues(sizeX: Int, sizeY: Int, sizeZ: Int) -> [UInt16] {
        var values: [UInt16] = []
        values.reserveCapacity(sizeX * sizeY * sizeZ)
        for z in 0..<sizeZ {
            for y in 0..<sizeY {
                for x in 0..<sizeX {
                    let value = x + y * 10 + z * 100
                    values.append(UInt16(value))
                }
            }
        }
        return values
    }

    private func assertSlicesEqual(_ gpu: CIImage2D, _ cpu: CIImage2D, tolerance: Int) {
        XCTAssertEqual(gpu.width, cpu.width)
        XCTAssertEqual(gpu.height, cpu.height)
        XCTAssertEqual(gpu.componentType, cpu.componentType)
        XCTAssertEqual(gpu.componentsPerPixel, cpu.componentsPerPixel)

        let gpuBytes = [UInt8](gpu.data)
        let cpuBytes = [UInt8](cpu.data)
        XCTAssertEqual(gpuBytes.count, cpuBytes.count)
        for (index, pair) in zip(gpuBytes, cpuBytes).enumerated() {
            let diff = abs(Int(pair.0) - Int(pair.1))
            XCTAssertLessThanOrEqual(diff, tolerance, "Mismatch at index \(index): cpu=\(pair.1) gpu=\(pair.0)")
        }
    }
}
