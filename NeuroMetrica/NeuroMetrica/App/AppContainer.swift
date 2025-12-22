import SwiftUI
import Observation

/// AppContainer = composition root for the UI shell.
///
/// For now, this owns the canonical viewer mockup state:
/// - `ViewerState` (UI layout + tools)
/// - `inspectorPresented` (whether the inspector column is visible)
///
/// It injects `ViewerState` into the environment so all viewer views
/// (ContentView, CanvasView, ViewportView, InspectorView, etc.)
/// can access it via `@Environment(ViewerState.self)`.
/// Later we will extend this to also create and inject shared services
/// and feature view models (ViewerViewModel, ImportViewModel, etc.).
struct AppContainer: View {
    @State private var viewerState: ViewerState
    @State private var inspectorPresented: Bool = true
    @StateObject private var appSettings: AppSettings
    @StateObject private var viewerViewModel: ViewerViewModel
    @StateObject private var recentFilesStore: RecentFilesStore
    @StateObject private var importViewModel: ImportViewModel

    init() {
        let viewerState = ViewerState()
        let appSettings = AppSettings()
        let engineBridge = ChromaEngineBridge(config: .standard)
        let recentFilesStore = RecentFilesStore()
        let filePickerService = FilePickerService()
        let viewerViewModel = ViewerViewModel(
            viewerState: viewerState,
            engineBridge: engineBridge,
            appSettings: appSettings,
            recentFilesStore: recentFilesStore
        )
        let importViewModel = ImportViewModel(
            filePickerService: filePickerService,
            recentFilesStore: recentFilesStore,
            viewerViewModel: viewerViewModel
        )

        _viewerState = State(initialValue: viewerState)
        _appSettings = StateObject(wrappedValue: appSettings)
        _viewerViewModel = StateObject(wrappedValue: viewerViewModel)
        _recentFilesStore = StateObject(wrappedValue: recentFilesStore)
        _importViewModel = StateObject(wrappedValue: importViewModel)
    }

    var body: some View {
        ContentView(
            viewModel: viewerViewModel,
            importViewModel: importViewModel,
            inspectorPresented: $inspectorPresented
        )
            .environment(viewerState)
            .environmentObject(appSettings)
    }
}

// MARK: - Preview

#Preview("AppContainer") {
    AppContainer()
}
