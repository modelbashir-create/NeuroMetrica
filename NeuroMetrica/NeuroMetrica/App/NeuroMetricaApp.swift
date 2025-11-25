import SwiftUI

@main
struct NeuroMetricaApp: App {
    @StateObject private var appContainer = AppContainer()

    var body: some Scene {
        WindowGroup {
            ViewerView(viewModel: appContainer.viewerViewModel)
                .environmentObject(appContainer.appSettings)
        }
    }
}
