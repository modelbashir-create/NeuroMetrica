//
//  NeuroMetricaTests.swift
//  NeuroMetricaTests
//
//  Created by Mohamed Elbashir on 11/12/25.
//

import XCTest
@testable import NeuroMetrica

final class NeuroMetricaTests: XCTestCase {

    @MainActor
    func testLayoutClampsActiveViewportAndDefaultsOrientation() {
        let state = ViewerState()
        state.activeViewportIndex = 3
        state.setLayout(.twoUp)

        XCTAssertEqual(state.clampedActiveIndex, 1)
        XCTAssertEqual(state.orientation(for: 0), .axial)
        XCTAssertEqual(state.orientation(for: 1), .sagittal)
    }

    @MainActor
    func testCineStopsWhenSliceCountIsOne() {
        let state = ViewerState()
        let engineBridge = ChromaEngineBridge(config: .standard)
        let appSettings = AppSettings()
        let recentFilesStore = RecentFilesStore()
        let viewModel = ViewerViewModel(
            viewerState: state,
            engineBridge: engineBridge,
            appSettings: appSettings,
            recentFilesStore: recentFilesStore
        )

        state.sliceCount = 1
        viewModel.startCine(for: 0)

        XCTAssertFalse(state.cineState(for: 0).isPlaying)
    }

    @MainActor
    func testLayoutChangePreservesCineStateForViewport() {
        let state = ViewerState()
        state.setCinePlaying(true, for: 0)
        state.activeViewportIndex = 3

        state.setLayout(.twoUp)

        XCTAssertEqual(state.clampedActiveIndex, 1)
        XCTAssertTrue(state.cineState(for: 0).isPlaying)
    }

    @MainActor
    func testSearchFiltersStudies() {
        let state = ViewerState()
        let engineBridge = ChromaEngineBridge(config: .standard)
        let appSettings = AppSettings()
        let recentFilesStore = RecentFilesStore()
        let viewerViewModel = ViewerViewModel(
            viewerState: state,
            engineBridge: engineBridge,
            appSettings: appSettings,
            recentFilesStore: recentFilesStore
        )
        let importViewModel = ImportViewModel(
            filePickerService: FilePickerService(),
            recentFilesStore: recentFilesStore,
            viewerViewModel: viewerViewModel
        )

        let studies = [
            Study(
                id: "1",
                title: "MR Brain",
                modality: "MR",
                date: .now,
                patientName: "DOE, JOHN",
                accessionNumber: "ACC-123",
                seriesCount: 1,
                sourceURL: URL(fileURLWithPath: "/tmp/brain"),
                series: [
                    StudySeries(
                        id: "series-1",
                        seriesDescription: "Brain",
                        seriesNumber: "1",
                        modality: "MR",
                        imagesCount: 10,
                        sourceURL: URL(fileURLWithPath: "/tmp/brain")
                    )
                ]
            ),
            Study(
                id: "2",
                title: "CT Chest",
                modality: "CT",
                date: .now,
                patientName: "SMITH, JANE",
                accessionNumber: "ACC-456",
                seriesCount: 1,
                sourceURL: URL(fileURLWithPath: "/tmp/chest"),
                series: [
                    StudySeries(
                        id: "series-2",
                        seriesDescription: "Chest",
                        seriesNumber: "2",
                        modality: "CT",
                        imagesCount: 20,
                        sourceURL: URL(fileURLWithPath: "/tmp/chest")
                    )
                ]
            )
        ]

        studies.forEach { recentFilesStore.upsertStudy($0) }

        importViewModel.searchText = "ct"
        XCTAssertEqual(importViewModel.filteredStudies.count, 1)
        XCTAssertEqual(importViewModel.filteredStudies.first?.modality, "CT")

        importViewModel.searchText = ""
        XCTAssertEqual(importViewModel.filteredStudies.count, 2)
    }
}
