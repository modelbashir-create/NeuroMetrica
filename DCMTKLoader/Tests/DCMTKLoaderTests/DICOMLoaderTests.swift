//
//  DICOMLoaderTests.swift
//  DCMTKLoader
//
//  Basic smoke test for the Swift loader surface.
//

import XCTest
@testable import DCMTKLoader

final class DICOMLoaderTests: XCTestCase {
    func testLoadSeriesPlaceholder() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let path = environment["DCMTK_TEST_SERIES_PATH"], FileManager.default.fileExists(atPath: path) else {
            throw XCTSkip("Sample DICOM series not available; set DCMTK_TEST_SERIES_PATH to a directory containing DICOM slices to enable this test.")
        }

        let url = URL(fileURLWithPath: path)
        let export = try DICOMLoader.loadSeries(at: url)

        XCTAssertGreaterThan(export.width, 0)
        XCTAssertGreaterThan(export.height, 0)
        XCTAssertGreaterThan(export.depth, 0)
        XCTAssertEqual(export.voxels.count, export.width * export.height * export.depth)
        XCTAssertEqual(export.metadata.numberOfSlices, export.depth)
        XCTAssertNotNil(export.metadata.pixelSpacing)
        XCTAssertNotNil(export.metadata.allTags["0010,0010"]) // patient name or similar tag should be recorded when present
    }
}
