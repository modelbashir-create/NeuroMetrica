import Foundation
import Combine
import ChromaImagingKit

enum ProcessingBackend: String, CaseIterable, Identifiable {
    case cpu
    case gpu

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cpu:
            return "CPU"
        case .gpu:
            return "GPU"
        }
    }

    var chromaBackend: ChromaProcessingBackend {
        switch self {
        case .cpu:
            return .cpu
        case .gpu:
            return .gpu
        }
    }
}

final class AppSettings: ObservableObject {
    private enum Keys {
        static let processingBackend = "processingBackend"
    }

    private let defaults: UserDefaults

    @Published var processingBackend: ProcessingBackend {
        didSet {
            defaults.set(processingBackend.rawValue, forKey: Keys.processingBackend)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let stored = defaults.string(forKey: Keys.processingBackend),
           let backend = ProcessingBackend(rawValue: stored) {
            processingBackend = backend
        } else {
            processingBackend = .gpu
        }
    }
}
