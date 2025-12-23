import Combine
import Foundation

@MainActor
final class LoadingViewModel: ObservableObject {
    @Published var progress: CGFloat = 0.0
    @Published var isFinished: Bool = false
    @Published var laserFade: CGFloat = 1.0

    let duration: TimeInterval = 3.5
    let laserFadeDuration: TimeInterval = 0.2
    let laserFadeStartOffset: TimeInterval = 0.2
    private var transitionTask: Task<Void, Never>?

    func start() {
        transitionTask?.cancel()
        progress = 0.0
        laserFade = 1.0
        isFinished = false

        transitionTask = Task { @MainActor [duration, laserFadeDuration, laserFadeStartOffset] in
            let fadeStartDelay = max(0, duration - laserFadeStartOffset)
            try? await Task.sleep(nanoseconds: UInt64(fadeStartDelay * 1_000_000_000))
            if Task.isCancelled { return }
            laserFade = 0.0
            try? await Task.sleep(nanoseconds: UInt64((laserFadeDuration + 0.05) * 1_000_000_000))
            if Task.isCancelled { return }
            isFinished = true
        }
    }

    deinit {
        transitionTask?.cancel()
    }
}
