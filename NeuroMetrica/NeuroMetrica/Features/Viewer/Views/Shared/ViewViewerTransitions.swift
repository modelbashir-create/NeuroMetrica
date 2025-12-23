import SwiftUI

// MARK: - iOS 26 Transition Helpers

extension View {
    @ViewBuilder
    func applyTransitionSource(id: String, in namespace: Namespace.ID) -> some View {
        #if swift(>=6.0)
        if #available(iOS 26, macOS 26, *) {
            self.matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
        #else
        self
        #endif
    }

    @ViewBuilder
    func applyMorphingTransition(id: String, in namespace: Namespace.ID) -> some View {
        #if swift(>=6.0)
        if #available(iOS 26, macOS 26, *) {
            self.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
        #else
        self
        #endif
    }
}
