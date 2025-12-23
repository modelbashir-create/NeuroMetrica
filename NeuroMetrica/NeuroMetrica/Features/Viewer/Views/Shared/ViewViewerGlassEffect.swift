import SwiftUI

// MARK: - iOS 26 Glass Effect

extension View {
    @ViewBuilder
    func applyGlassEffect(tint: Color = .black.opacity(0.3), cornerRadius: CGFloat = 8) -> some View {
        #if swift(>=6.0)
        if #available(iOS 26, macOS 26, *) {
            self.glassEffect(.regular.tint(tint), in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(tint.opacity(0.5), in: RoundedRectangle(cornerRadius: cornerRadius))
        }
        #else
        self.background(tint.opacity(0.5), in: RoundedRectangle(cornerRadius: cornerRadius))
        #endif
    }
}
