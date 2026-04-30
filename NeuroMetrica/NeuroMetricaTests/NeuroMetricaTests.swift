//
//  NeuroMetricaTests.swift
//  NeuroMetricaTests
//
//  Created by Mohamed Elbashir on 11/12/25.
//

import XCTest
import simd
import ChromaEngineKit
@testable import NeuroMetrica

private struct RecordedOpenVolumeCall: Equatable {
    let url: URL
    let selection: DicomImportSelection?
}

@MainActor
private final class MockVolumeRouter: VolumeOpenRouting {
    private(set) var openVolumeCalls: [RecordedOpenVolumeCall] = []

    func openVolume(from url: URL) async {
        await openVolume(from: url, dicomSelection: nil)
    }

    func openVolume(from url: URL, dicomSelection: DicomImportSelection?) async {
        openVolumeCalls.append(
            RecordedOpenVolumeCall(url: url, selection: dicomSelection)
        )
    }

    func openVolumes(from urls: [URL]) async {
        for url in urls {
            await openVolume(from: url, dicomSelection: nil)
        }
    }

    func openStudy(_ study: Study) async {}

    func openSeries(_ series: StudySeries, study: Study?) async {}
}

private actor MockDicomImportInspector: DicomImportInspecting {
    private var inspectionsByPath: [String: DicomImportInspection?] = [:]

    func setInspection(_ inspection: DicomImportInspection?, for url: URL) {
        inspectionsByPath[url.path] = inspection
    }

    func inspectImport(at url: URL) async throws -> DicomImportInspection? {
        inspectionsByPath[url.path] ?? nil
    }
}

final class NeuroMetricaTests: XCTestCase {

    @MainActor
    func testRenderingBackendDefaultIsAutomatic() {
        let key = "appSettings.renderingBackendPreference"
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: key)
        defaults.removeObject(forKey: key)
        defer {
            if let previous {
                defaults.set(previous, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        let settings = AppSettings()
        XCTAssertEqual(settings.renderingBackendPreference, .automatic)
    }

    @MainActor
    func testRenderingBackendLoadsPersistedPreference() {
        let key = "appSettings.renderingBackendPreference"
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: key)
        defaults.set(RenderingBackendPreference.cpu.rawValue, forKey: key)
        defer {
            if let previous {
                defaults.set(previous, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        let settings = AppSettings()
        XCTAssertEqual(settings.renderingBackendPreference, .cpu)
    }

    @MainActor
    func testLayoutClampsActiveViewportAndDefaultsOrientation() {
        let state = ViewerState()
        state.activeViewportIndex = 3
        state.setLayout(.twoUp)

        XCTAssertEqual(state.clampedActiveIndex, 0)
        XCTAssertEqual(state.orientation(for: 0), .axial)
        XCTAssertEqual(state.orientation(for: 1), .sagittal)
    }

    @MainActor
    func testCineStopsWhenSliceCountIsOne() async {
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

        let volume = makeTestVolume(size: 1)
        let descriptor = await engineBridge.registerVolumeForTesting(volume: volume)
        viewModel.installVolumeForTesting(descriptor)
        viewModel.startCine(for: 0)

        XCTAssertFalse(state.cineState(for: 0).isPlaying)
    }

    @MainActor
    func testLayoutChangePreservesCineStateForViewport() {
        let state = ViewerState()
        state.setCinePlaying(true, for: 0)
        state.activeViewportIndex = 3

        state.setLayout(.twoUp)

        XCTAssertEqual(state.clampedActiveIndex, 0)
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
            volumeRouter: viewerViewModel,
            dicomImportInspector: engineBridge
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

    @MainActor
    func testZoomClampsPerViewport() {
        let state = ViewerState()
        state.setZoom(0.1, for: 0)
        state.setZoom(10, for: 1)

        XCTAssertEqual(state.zoom(for: 0), ViewerState.minZoom)
        XCTAssertEqual(state.zoom(for: 1), ViewerState.maxZoom)
        XCTAssertEqual(state.zoom(for: 2), ViewerState.defaultZoom)
    }

    @MainActor
    func testViewModelZoomStepAndClamp() {
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

        viewModel.setZoom(for: 0, to: 3.0)
        viewModel.stepZoom(for: 0, by: 2.0)
        XCTAssertEqual(state.zoom(for: 0), ViewerState.maxZoom)

        viewModel.setZoom(for: 0, to: 1.0)
        viewModel.stepZoom(for: 0, by: 0.1)
        XCTAssertEqual(state.zoom(for: 0), ViewerState.minZoom)
    }

    @MainActor
    func testZoomIgnoredForNonImagingViewport() {
        let state = ViewerState()
        state.setLayout(.fourUp)

        let engineBridge = ChromaEngineBridge(config: .standard)
        let appSettings = AppSettings()
        let recentFilesStore = RecentFilesStore()
        let viewModel = ViewerViewModel(
            viewerState: state,
            engineBridge: engineBridge,
            appSettings: appSettings,
            recentFilesStore: recentFilesStore
        )

        viewModel.setZoom(for: 3, to: 2.0)
        XCTAssertEqual(state.zoom(for: 3), ViewerState.defaultZoom)
    }

    func testFilePickerServiceReturnsEachSelectedNonDicomTarget() {
        let service = FilePickerService()
        let urls = [
            URL(fileURLWithPath: "/tmp/a.nii"),
            URL(fileURLWithPath: "/tmp/b.nrrd")
        ]

        let targets = service.loadTargets(from: urls)

        XCTAssertEqual(targets, urls)
    }

    func testFilePickerServiceCollapsesMultipleDicomFilesFromSameDirectory() {
        let service = FilePickerService()
        let urls = [
            URL(fileURLWithPath: "/tmp/series/image-001.dcm"),
            URL(fileURLWithPath: "/tmp/series/image-002.dcm"),
            URL(fileURLWithPath: "/tmp/series/image-003.dcm")
        ]

        let targets = service.loadTargets(from: urls)

        XCTAssertEqual(targets, [URL(fileURLWithPath: "/tmp/series")])
    }

    @MainActor
    func testImportViewModelAutoLoadsRecommendedSelectionForCleanDicomImport() async {
        let recentFilesStore = RecentFilesStore()
        let router = MockVolumeRouter()
        let inspector = MockDicomImportInspector()
        let viewModel = ImportViewModel(
            filePickerService: FilePickerService(),
            recentFilesStore: recentFilesStore,
            volumeRouter: router,
            dicomImportInspector: inspector
        )

        let url = URL(fileURLWithPath: "/tmp/import/series-001")
        let selection = DicomImportSelection(seriesInstanceUID: "series-001", subseriesKey: "stack-a")
        let inspection = DicomImportInspection(
            options: [
                DicomImportOption(
                    selection: selection,
                    studyDescription: "Study",
                    seriesDescription: "Axial PD",
                    modality: "MR",
                    seriesNumber: "1",
                    fileCount: 24,
                    confidence: 5,
                    orientationConsistent: true,
                    spacingUniform: true,
                    spacingReferenceMm: 1.0,
                    maxSpacingErrorMm: 0.0,
                    reasons: [],
                    isRecommended: true
                )
            ],
            recommendedSelection: selection,
            selectionPolicy: "highest_confidence_then_file_count_then_uid"
        )

        await inspector.setInspection(inspection, for: url)
        await viewModel.processImportTargets([url])

        XCTAssertNil(viewModel.pendingDicomReviewSession)
        XCTAssertEqual(
            router.openVolumeCalls,
            [RecordedOpenVolumeCall(url: url, selection: selection)]
        )
    }

    @MainActor
    func testImportViewModelPresentsReviewForAmbiguousDicomImport() async {
        let recentFilesStore = RecentFilesStore()
        let router = MockVolumeRouter()
        let inspector = MockDicomImportInspector()
        let viewModel = ImportViewModel(
            filePickerService: FilePickerService(),
            recentFilesStore: recentFilesStore,
            volumeRouter: router,
            dicomImportInspector: inspector
        )

        let url = URL(fileURLWithPath: "/tmp/import/series-ambiguous")
        let recommendedSelection = DicomImportSelection(seriesInstanceUID: "series-001", subseriesKey: "stack-a")
        let alternateSelection = DicomImportSelection(seriesInstanceUID: "series-002", subseriesKey: "stack-b")
        let inspection = DicomImportInspection(
            options: [
                DicomImportOption(
                    selection: recommendedSelection,
                    studyDescription: "Study",
                    seriesDescription: "Axial PD",
                    modality: "MR",
                    seriesNumber: "1",
                    fileCount: 24,
                    confidence: 5,
                    orientationConsistent: true,
                    spacingUniform: true,
                    spacingReferenceMm: 1.0,
                    maxSpacingErrorMm: 0.0,
                    reasons: [],
                    isRecommended: true
                ),
                DicomImportOption(
                    selection: alternateSelection,
                    studyDescription: "Study",
                    seriesDescription: "Localizer",
                    modality: "MR",
                    seriesNumber: "2",
                    fileCount: 3,
                    confidence: 2,
                    orientationConsistent: false,
                    spacingUniform: false,
                    spacingReferenceMm: nil,
                    maxSpacingErrorMm: nil,
                    reasons: ["localizerLike"],
                    isRecommended: false
                )
            ],
            recommendedSelection: recommendedSelection,
            selectionPolicy: "highest_confidence_then_file_count_then_uid"
        )

        await inspector.setInspection(inspection, for: url)
        await viewModel.processImportTargets([url])

        XCTAssertEqual(router.openVolumeCalls.count, 0)
        XCTAssertEqual(viewModel.pendingDicomReviewSession?.sourceURL, url)
        XCTAssertEqual(viewModel.pendingDicomReviewSession?.selectedOptionID, inspection.recommendedOptionID)

        viewModel.confirmPendingDicomReview()
        try? await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertNil(viewModel.pendingDicomReviewSession)
        XCTAssertEqual(
            router.openVolumeCalls,
            [RecordedOpenVolumeCall(url: url, selection: recommendedSelection)]
        )
    }

    @MainActor
    func testMPRCrosshairRefreshRequestsAllPanes() async {
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

        let volume = makeTestVolume(size: 3)
        let descriptor = await engineBridge.registerVolumeForTesting(volume: volume)
        viewModel.installVolumeForTesting(descriptor)

        state.viewerMode = .mpr
        state.mprCrosshairPoint = SIMD3<Double>(0.0, 0.0, 0.0)
        viewModel.setMPRCrosshairPoint(SIMD3<Double>(1.0, 1.0, 1.0))

        try? await Task.sleep(nanoseconds: 40_000_000)
        XCTAssertEqual(viewModel.debugRequestedMPRPanes(), Set(MPRPane.allCases))
    }

    @MainActor
    func testSelectingMPRPreservesSelectedThreePaneLayout() {
        let state = ViewerState()
        state.layoutMode = .oneUp
        state.mprLayoutMode = .threeUp

        let engineBridge = ChromaEngineBridge(config: .standard)
        let appSettings = AppSettings()
        let recentFilesStore = RecentFilesStore()
        let viewModel = ViewerViewModel(
            viewerState: state,
            engineBridge: engineBridge,
            appSettings: appSettings,
            recentFilesStore: recentFilesStore
        )

        viewModel.selectReformatMode(.mpr)

        XCTAssertEqual(state.viewerMode, .mpr)
        XCTAssertEqual(state.mprLayoutMode, .threeUp)
    }

    @MainActor
    func testResetViewPresentationRestoresDisplayDefaultsWithoutUnloadingVolume() async {
        let state = ViewerState()
        state.layoutMode = .threeUp
        state.activeViewportIndex = 2
        state.viewerMode = .mpr
        state.mprLayoutMode = .threeUp

        let engineBridge = ChromaEngineBridge(config: .standard)
        let appSettings = AppSettings()
        appSettings.defaultWindow = 410
        appSettings.defaultLevel = 55
        let recentFilesStore = RecentFilesStore()
        let viewModel = ViewerViewModel(
            viewerState: state,
            engineBridge: engineBridge,
            appSettings: appSettings,
            recentFilesStore: recentFilesStore
        )

        let volume = makeTestVolume(size: 5)
        let descriptor = await engineBridge.registerVolumeForTesting(volume: volume)
        viewModel.installVolumeForTesting(descriptor)

        state.setOrientation(.coronal, for: 0)
        state.setOrientation(.axial, for: 1)
        state.setOrientation(.sagittal, for: 2)
        state.window = 1200
        state.level = -200
        state.setPatientPoint(SIMD3<Double>(0, 0, 0), for: 0)
        state.setPatientPoint(SIMD3<Double>(0, 0, 0), for: 2)
        state.setZoom(2.4, for: 0)
        state.setPan(CGSize(width: 18, height: -12), for: 0)
        state.setZoom(1.8, for: 3)
        state.setPan(CGSize(width: -9, height: 11), for: 3)
        state.setCinePlaying(true, for: 0)
        state.mprCrosshairPoint = SIMD3<Double>(0, 0, 0)
        state.mprActivePane = .sagittal
        state.mprOrientationMap = [
            .axial: .sagittal,
            .coronal: .axial,
            .sagittal: .coronal
        ]

        viewModel.resetViewPresentation()

        XCTAssertTrue(state.hasVolume)
        XCTAssertEqual(state.layoutMode, .threeUp)
        XCTAssertEqual(state.activeViewportIndex, 2)
        XCTAssertEqual(state.viewerMode, .mpr)
        XCTAssertEqual(state.mprLayoutMode, .threeUp)
        XCTAssertEqual(state.orientation(for: 0), .axial)
        XCTAssertEqual(state.orientation(for: 1), .sagittal)
        XCTAssertEqual(state.orientation(for: 2), .coronal)
        XCTAssertEqual(state.baselineWindow, Float(appSettings.defaultWindow))
        XCTAssertEqual(state.baselineLevel, Float(appSettings.defaultLevel))
        XCTAssertEqual(state.window, Float(appSettings.defaultWindow))
        XCTAssertEqual(state.level, Float(appSettings.defaultLevel))
        XCTAssertEqual(viewModel.sliceInfo(for: 0)?.displayIndex, 2)
        XCTAssertEqual(viewModel.sliceInfo(for: 2)?.displayIndex, 2)
        XCTAssertEqual(state.zoom(for: 0), ViewerState.defaultZoom)
        XCTAssertEqual(state.zoom(for: 3), ViewerState.defaultZoom)
        XCTAssertEqual(state.pan(for: 0), .zero)
        XCTAssertEqual(state.pan(for: 3), .zero)
        XCTAssertEqual(state.patientPoint(for: 2), SIMD3<Double>(2, 2, 2))
        XCTAssertFalse(state.cineState(for: 0).isPlaying)
        XCTAssertEqual(state.mprCrosshairPoint, SIMD3<Double>(2, 2, 2))
        XCTAssertEqual(state.mprActivePane, .axial)
        XCTAssertEqual(state.mprOrientationMap, ViewerState.defaultMPROrientationMap)
    }

    @MainActor
    func testViewportSliceStateIsIndependentPerViewport() async {
        let state = ViewerState()
        state.layoutMode = .threeUp

        let engineBridge = ChromaEngineBridge(config: .standard)
        let appSettings = AppSettings()
        let recentFilesStore = RecentFilesStore()
        let viewModel = ViewerViewModel(
            viewerState: state,
            engineBridge: engineBridge,
            appSettings: appSettings,
            recentFilesStore: recentFilesStore
        )

        let volume = makeTestVolume(size: 5)
        let descriptor = await engineBridge.registerVolumeForTesting(volume: volume)
        viewModel.installVolumeForTesting(descriptor)

        viewModel.setSliceIndex(0, for: 0)
        viewModel.setSliceIndex(4, for: 1)
        viewModel.setSliceIndex(1, for: 2)

        XCTAssertEqual(viewModel.sliceInfo(for: 0)?.displayIndex, 0)
        XCTAssertEqual(viewModel.sliceInfo(for: 1)?.displayIndex, 4)
        XCTAssertEqual(viewModel.sliceInfo(for: 2)?.displayIndex, 1)
        XCTAssertEqual(state.patientPoint(for: 0), SIMD3<Double>(2, 2, 4))
        XCTAssertEqual(state.patientPoint(for: 1), SIMD3<Double>(0, 2, 2))
        XCTAssertEqual(state.patientPoint(for: 2), SIMD3<Double>(2, 3, 2))

        viewModel.stepSlice(by: 1, for: 0)

        XCTAssertEqual(viewModel.sliceInfo(for: 0)?.displayIndex, 1)
        XCTAssertEqual(viewModel.sliceInfo(for: 1)?.displayIndex, 4)
        XCTAssertEqual(viewModel.sliceInfo(for: 2)?.displayIndex, 1)
    }

    @MainActor
    func testInstallVolumeUsesDicomWindowLevelBaselineAndResetRestoresIt() async {
        let state = ViewerState()
        let engineBridge = ChromaEngineBridge(config: .standard)
        let appSettings = AppSettings()
        appSettings.defaultWindow = 410
        appSettings.defaultLevel = 55
        let recentFilesStore = RecentFilesStore()
        let viewModel = ViewerViewModel(
            viewerState: state,
            engineBridge: engineBridge,
            appSettings: appSettings,
            recentFilesStore: recentFilesStore
        )

        let metadata = CIMetadata(
            sourceFormat: .dicom,
            windowCenter: [32, 80],
            windowWidth: [640, 1600]
        )
        let volume = makeTestVolume(size: 5)
        let descriptor = await engineBridge.registerVolumeForTesting(volume: volume, metadata: metadata)

        viewModel.installVolumeForTesting(descriptor)

        XCTAssertEqual(state.dicomWindowLevelPresets.count, 2)
        XCTAssertEqual(state.baselineWindow, 640)
        XCTAssertEqual(state.baselineLevel, 32)
        XCTAssertEqual(state.window, 640)
        XCTAssertEqual(state.level, 32)

        state.window = 1200
        state.level = -100

        viewModel.resetViewPresentation()

        XCTAssertEqual(state.baselineWindow, 640)
        XCTAssertEqual(state.baselineLevel, 32)
        XCTAssertEqual(state.window, 640)
        XCTAssertEqual(state.level, 32)
    }

    @MainActor
    func testResetViewPresentationUsesStoredBaselineForNonDicomSeries() async {
        let state = ViewerState()
        let engineBridge = ChromaEngineBridge(config: .standard)
        let appSettings = AppSettings()
        appSettings.defaultWindow = 410
        appSettings.defaultLevel = 55
        let recentFilesStore = RecentFilesStore()
        let viewModel = ViewerViewModel(
            viewerState: state,
            engineBridge: engineBridge,
            appSettings: appSettings,
            recentFilesStore: recentFilesStore
        )

        let volume = makeTestVolume(size: 5)
        let descriptor = await engineBridge.registerVolumeForTesting(volume: volume)

        viewModel.installVolumeForTesting(descriptor)

        XCTAssertEqual(state.baselineWindow, 410)
        XCTAssertEqual(state.baselineLevel, 55)
        XCTAssertEqual(state.window, 410)
        XCTAssertEqual(state.level, 55)

        appSettings.defaultWindow = 900
        appSettings.defaultLevel = 125
        state.window = 1200
        state.level = -100

        viewModel.resetViewPresentation()

        XCTAssertEqual(state.baselineWindow, 410)
        XCTAssertEqual(state.baselineLevel, 55)
        XCTAssertEqual(state.window, 410)
        XCTAssertEqual(state.level, 55)
    }

    func testMPRCrosshairAxisColors() {
        let axialAxes = MPRCrosshairStyle.axes(for: .axial)
        XCTAssertEqual(axialAxes.axisU, .x)
        XCTAssertEqual(axialAxes.axisV, .y)

        let coronalAxes = MPRCrosshairStyle.axes(for: .coronal)
        XCTAssertEqual(coronalAxes.axisU, .x)
        XCTAssertEqual(coronalAxes.axisV, .z)

        let sagittalAxes = MPRCrosshairStyle.axes(for: .sagittal)
        XCTAssertEqual(sagittalAxes.axisU, .y)
        XCTAssertEqual(sagittalAxes.axisV, .z)
    }

    @MainActor
    func testMPRScrollUpdatesCrosshairAlongNormal() async {
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

        let volume = makeTestVolume(size: 5)
        let descriptor = await engineBridge.registerVolumeForTesting(volume: volume)
        viewModel.installVolumeForTesting(descriptor)

        state.viewerMode = .mpr
        state.mprCrosshairPoint = SIMD3<Double>(2.0, 2.0, 2.0)

        viewModel.stepMPRSlice(by: 1, pane: .axial)
        try? await Task.sleep(nanoseconds: 20_000_000)

        let updated = state.mprCrosshairPoint
        XCTAssertEqual(updated?.x, 2.0)
        XCTAssertEqual(updated?.y, 2.0)
        XCTAssertEqual(updated?.z, 3.0)
    }

    func testClampPatientPoint() {
        let volume = makeTestVolume(size: 4)
        let point = SIMD3<Double>(10.0, -5.0, 2.0)
        let clamped = ChromaEngineBridge.clampPatientPoint(volume: volume, point: point)

        XCTAssertEqual(clamped.x, 3.0)
        XCTAssertEqual(clamped.y, 0.0)
        XCTAssertEqual(clamped.z, 2.0)
    }

    func testCanonicalPlaneRespectsDirectionColumns() {
        let volume = makeTestVolume(
            size: 4,
            direction: [
                0, 1, 0, 0,
                1, 0, 0, 0,
                0, 0, 1, 0,
                0, 0, 0, 1
            ]
        )

        let plane = ChromaEngineBridge.makeCanonicalPlane(
            volume: volume,
            orientation: .axial,
            crosshairPoint: SIMD3<Double>(0.0, 0.0, 0.0)
        )

        XCTAssertEqual(plane.axisU, SIMD3<Double>(0, 1, 0))
        XCTAssertEqual(plane.axisV, SIMD3<Double>(1, 0, 0))
        XCTAssertEqual(plane.spacingU, 1.0)
        XCTAssertEqual(plane.spacingV, 1.0)
    }

    private func makeTestVolume(
        size: Int,
        direction: [Double] = [
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            0, 0, 0, 1
        ]
    ) -> CImageVolume {
        let voxelCount = size * size * size
        let bytesPerComponent = 2
        let data = Data(count: voxelCount * bytesPerComponent)

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
            direction: direction,
            componentType: .uint16,
            componentsPerPixel: 1,
            bytesPerComponent: bytesPerComponent,
            isSigned: false,
            rescaleSlope: 1.0,
            rescaleIntercept: 0.0,
            voxelData: data
        )
    }
}
