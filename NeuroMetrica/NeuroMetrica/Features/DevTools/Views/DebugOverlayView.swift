import SwiftUI

struct DebugOverlayView: View {
    @ObservedObject var viewModel: DebugOverlayViewModel

    var body: some View {
        if viewModel.isVisible {
            VStack(alignment: .leading, spacing: 8) {
                Text("Debug Overlay")
                    .font(.headline)
                if viewModel.statusText.isEmpty {
                    Text("No debug data available")
                        .foregroundStyle(.secondary)
                } else {
                    Text(viewModel.statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(.white)
        }
    }
}
