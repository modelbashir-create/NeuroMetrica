import SwiftUI

struct Placeholder3DView: View {
    var body: some View {
        VStack(spacing: 6) {
            Text("3D view not available yet")
                .font(.caption.bold())
                .foregroundStyle(.white)
            Text("Coming soon")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }
}
