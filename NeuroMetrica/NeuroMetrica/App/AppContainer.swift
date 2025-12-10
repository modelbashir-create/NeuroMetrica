import SwiftUI

/// AppContainer = composition root for the UI shell.
/// Right now it just hosts the new ContentView and owns the inspector visibility.
/// Later we’ll let this create and inject shared services + view models.
struct AppContainer: View {
    @State private var inspectorPresented: Bool = true

    var body: some View {
        ContentView(inspectorPresented: $inspectorPresented)
    }
}

// MARK: - Preview

#Preview("AppContainer") {
    AppContainer()
}
