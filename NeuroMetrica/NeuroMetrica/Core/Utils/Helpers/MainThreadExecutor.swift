import Foundation

/// Small helper to ensure UI work runs on the main thread.
enum MainThreadExecutor {
    static func run(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async {
                block()
            }
        }
    }
}
