import Foundation
import Combine
import ChromaImagingKit

final class AppContainer: ObservableObject {
    let appSettings: AppSettings
    let engineBridge: ChromaEngineBridge
    let viewerViewModel: ViewerViewModel
    private var cancellables = Set<AnyCancellable>()

    init(appSettings: AppSettings = AppSettings()) {
        self.appSettings = appSettings

        let engine = ChromaEngine(backend: appSettings.processingBackend.chromaBackend)
        let engineBridge = ChromaEngineBridge(engine: engine)
        self.engineBridge = engineBridge

        self.viewerViewModel = ViewerViewModel(
            engineBridge: engineBridge
        )

        appSettings.$processingBackend
            .sink { [weak engineBridge] backend in
                engineBridge?.updateBackend(backend.chromaBackend)
            }
            .store(in: &cancellables)
    }
}
