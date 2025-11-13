import SwiftUI

/// Simple dependency container so wiring is in one place.
final class AppContainer {
    private let studyBrowser: StudyBrowser
    private let sliceGenerator: SliceGenerator

    init() {
        // For now: dummy implementations. Later we swap for DCMTK/NIfTI/etc.
        self.studyBrowser = DummyStudyBrowser()
        self.sliceGenerator = CPUSliceGenerator()
    }

    func makeRootView() -> some View {
        let vm = ViewerViewModel(studyBrowser: studyBrowser,
                                 slicer: sliceGenerator)
        return ViewerView(viewModel: vm)
    }
}