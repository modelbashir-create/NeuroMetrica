import XCTest
@testable import ChromaImagingCore
import ITKBridge

final class ImagingCoreTests: XCTestCase {
    func testVolumeInit() throws {
        let dims = (x: 8, y: 8, z: 8, t: 1)
        let spacing = (x: 1.0, y: 1.0, z: 1.0)
        let origin = (x: 0.0, y: 0.0, z: 0.0)
        let dir: [Double] = [
            1, 0, 0,
            0, 1, 0,
            0, 0, 1
        ]
        let dataSize = dims.x * dims.y * dims.z * MemoryLayout<Int16>.size
        let data = Data(count: dataSize)

        let volume = try NMVolume(
            dimensions: dims,
            spacing: spacing,
            origin: origin,
            direction: dir,
            scalarType: .int16,
            data: data
        )

        XCTAssertEqual(volume.dimensions.x, 8)
        XCTAssertEqual(volume.direction.count, 9)
        XCTAssertEqual(volume.data.count, dataSize)
    }

    func testITKDescriptorParsesBooleanMetadataJSON() {
        let json = """
        {
          "0008,0060": "MR",
          "0008,1030": "Knee (R)",
          "0008,103e": "AX.  FSE PD",
          "_orientationConsistent": true
        }
        """

        let jsonPointer = strdup(json)
        XCTAssertNotNil(jsonPointer)
        guard let jsonPointer else {
            return
        }

        var descriptorC = ITKImageDescriptorC()
        descriptorC.dimension = 3
        descriptorC.metadataJSON = UnsafePointer(jsonPointer)
        descriptorC.metadataJSONLength = Int32(strlen(jsonPointer))

        let descriptor = ITKImageDescriptor(cDescriptor: descriptorC)

        XCTAssertEqual(descriptor.metadata["0008,0060"], .string("MR"))
        XCTAssertEqual(descriptor.metadata["0008,1030"], .string("Knee (R)"))
        XCTAssertEqual(descriptor.metadata["0008,103e"], .string("AX.  FSE PD"))
        XCTAssertEqual(descriptor.metadata["_orientationConsistent"], .boolean(true))

        descriptor.freeBridgeResources()
    }

    func testITKDescriptorParsesMetadataJSONWithNestedObjects() {
        let json = """
        {
          "_geometryValidation": {
            "sliceOrder": "monotonic",
            "spacing": {
              "uniform": true,
              "min": 4.5,
              "max": 4.5
            },
            "direction": {
              "orthonormal": true,
              "determinant": 1.0,
              "leftHanded": false
            },
            "usedDefaults": false,
            "validationStatus": "ok"
          },
          "0008,0060": "MR",
          "0008,1030": "Knee (R)",
          "0008,103e": "AX.  FSE PD",
          "_orientationConsistent": true,
          "0020,0011": 5
        }
        """

        let jsonPointer = strdup(json)
        XCTAssertNotNil(jsonPointer)
        guard let jsonPointer else {
            return
        }

        var descriptorC = ITKImageDescriptorC()
        descriptorC.dimension = 3
        descriptorC.metadataJSON = UnsafePointer(jsonPointer)
        descriptorC.metadataJSONLength = Int32(strlen(jsonPointer))

        let descriptor = ITKImageDescriptor(cDescriptor: descriptorC)

        XCTAssertEqual(descriptor.metadata["0008,0060"], .string("MR"))
        XCTAssertEqual(descriptor.metadata["0008,1030"], .string("Knee (R)"))
        XCTAssertEqual(descriptor.metadata["0008,103e"], .string("AX.  FSE PD"))
        XCTAssertEqual(descriptor.metadata["_orientationConsistent"], .boolean(true))
        XCTAssertEqual(descriptor.metadata["0020,0011"], .number(5))

        descriptor.freeBridgeResources()
    }
}
