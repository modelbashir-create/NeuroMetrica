import SwiftUI

@main
struct finaluiApp: App {
    @State private var viewerState = ViewerState()
    @State private var inspectorPresented = true
    
    var body: some Scene {
        WindowGroup {
            ContentView(inspectorPresented: $inspectorPresented)
                .environment(viewerState)  // ← This is required
        }
    }
}
