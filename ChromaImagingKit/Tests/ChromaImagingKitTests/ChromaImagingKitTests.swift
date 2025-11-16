import XCTest
@testable import ChromaImagingKit

final class ChromaImagingKitTests: XCTestCase {
    func testExample() throws {
        // XCTest Documentation
        // https://developer.apple.com/documentation/xctest

        // Defining Test Cases and Test Methods
        // https://developer.apple.com/documentation/xctest/defining_test_cases_and_test_methods
    }
    func testNIfTILoadsVolumeMetadata() throws {
        // This is a smoke test for the NIfTILoader/CNifti bridge.
        // It expects a test NIfTI file named "TestVolume.nii.gz" to be present
        // in the ChromaImagingKitTests resources (declared in Package.swift).
        //
        // If the file is not present yet, we skip the test instead of failing hard.
        guard let url = Bundle.module.url(forResource: "TestVolume", withExtension: "nii.gz") else {
            throw XCTSkip("TestVolume.nii.gz not found in test resources; add it to ChromaImagingKitTests resources to enable this test.")
        }
        
        let loader = NIfTILoader()
        let volume = try loader.loadVolume(from: url)
        
        // Basic sanity checks on dimensions
        XCTAssertGreaterThan(volume.width, 0, "Width should be > 0")
        XCTAssertGreaterThan(volume.height, 0, "Height should be > 0")
        XCTAssertGreaterThan(volume.depth, 0, "Depth should be > 0")
    }
}
