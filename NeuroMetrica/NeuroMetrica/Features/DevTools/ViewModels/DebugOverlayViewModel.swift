import Combine
import Foundation

@MainActor
final class DebugOverlayViewModel: ObservableObject {
    @Published var isVisible: Bool = false
    @Published var statusText: String = ""

    func toggle() {
        isVisible.toggle()
    }
}
