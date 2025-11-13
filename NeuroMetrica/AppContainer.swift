//
//  AppContainer.swift
//  NeuroMetrica
//
//  Created by Mohamed Elbashir on 11/12/25.
//


import SwiftUI

/// Simple dependency container so wiring is in one place.
final class AppContainer {
    private let studyBrowser: StudyBrowser
    private let sliceGenerator: SliceGenerator
    private let volumeProcessor: VolumeProcessing

    init() {
        // For now: dummy implementations. Later we swap for DCMTK/NIfTI/etc.
        self.studyBrowser = DummyStudyBrowser()
        self.sliceGenerator = CPUSliceGenerator()
        self.volumeProcessor = ITKVolumeProcessor()
    }

    func makeRootView() -> some View {
        let vm = ViewerViewModel(studyBrowser: studyBrowser,
                                 slicer: sliceGenerator)
        return ViewerView(viewModel: vm)
    }
}
