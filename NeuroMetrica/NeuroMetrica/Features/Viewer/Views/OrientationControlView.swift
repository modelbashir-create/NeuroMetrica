import SwiftUI
import ChromaImagingKit

struct OrientationControlView: View {
    @ObservedObject var viewModel: ViewerViewModel

    var body: some View {
        HStack {
            Text("Orientation")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Picker("Orientation", selection: Binding(
                get: { viewModel.state.orientation },
                set: { newValue in
                    viewModel.setOrientation(newValue)
                }
            )) {
                Text("AX").tag(SliceOrientation.axial)
                Text("COR").tag(SliceOrientation.coronal)
                Text("SAG").tag(SliceOrientation.sagittal)
            }
            .pickerStyle(.segmented)
        }
    }
}
