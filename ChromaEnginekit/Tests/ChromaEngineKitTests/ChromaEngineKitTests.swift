import XCTest
@testable import ChromaEngineKit

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
}
