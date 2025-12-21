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
    @State private var viewerState = ViewerState()
    @State private var inspectorPresented: Bool = true

    var body: some View {
        ContentView(inspectorPresented: $inspectorPresented)
            .environment(viewerState)
    }
}

// MARK: - Preview

#Preview("AppContainer") {
    AppContainer()
}
