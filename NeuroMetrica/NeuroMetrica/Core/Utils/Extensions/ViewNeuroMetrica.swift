import SwiftUI

extension View {
    /// Conditionally hides a view without removing it from layout.
    @ViewBuilder
    func neurometricaHidden(_ hidden: Bool) -> some View {
        if hidden {
            self.hidden()
        } else {
            self
        }
    }
}
