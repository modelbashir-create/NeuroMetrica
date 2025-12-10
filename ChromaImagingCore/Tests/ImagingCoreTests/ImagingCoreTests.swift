import XCTest
@testable import ImagingCore

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

        let volume = NMVolume(
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
}
