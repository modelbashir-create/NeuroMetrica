import Foundation
import Combine

final class AppContainer: ObservableObject {
    let engineBridge: ChromaEngineBridge
    let viewerViewModel: ViewerViewModel

    init() {
        let engineBridge = ChromaEngineBridge()
        self.engineBridge = engineBridge

        self.viewerViewModel = ViewerViewModel(
            engineBridge: engineBridge
        )
    }
}
