import SwiftUI

@main
struct NeuroMetricaApp: App {
    private let container = AppContainer()

    var body: some Scene {
        WindowGroup {
            container.makeRootView()
        }
    }
}