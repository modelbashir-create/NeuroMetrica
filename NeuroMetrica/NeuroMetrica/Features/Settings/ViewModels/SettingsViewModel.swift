import Combine
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }
}
