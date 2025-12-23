import SwiftUI

struct ErrorOverlayView: View {
    let title: String
    let message: String
    let canRetry: Bool
    let onRetry: () -> Void
    let onChooseAnother: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.callout.bold())
                .foregroundStyle(.white)
            Text(message)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineLimit(3)

            HStack(spacing: 8) {
                Button("Try again", action: onRetry)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canRetry)

                Button("Choose another file…", action: onChooseAnother)
                    .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        )
    }
}
