
import SwiftUI

struct SliceNavigationView: View {
    @ObservedObject var viewModel: ViewerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Label: "Slice X / N"
            HStack {
                let sliceCount = viewModel.state.sliceCount
                let index = viewModel.state.sliceIndex

                Text("Slice \(sliceCount == 0 ? 0 : index + 1) / \(sliceCount)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()
            }

            // Slider for slice index (absolute control)
            Slider(
                value: Binding(
                    get: { Double(viewModel.state.sliceIndex) },
                    set: { newValue in
                        let intValue = Int(newValue.rounded())
                        viewModel.setSliceIndex(intValue)
                    }
                ),
                in: 0...Double(max(viewModel.state.sliceCount - 1, 0)),
                step: 1.0
            )
            .disabled(viewModel.state.sliceCount == 0)
        }
    }
}
