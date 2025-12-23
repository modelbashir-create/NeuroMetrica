import SwiftUI
import ChromaEngineKit

struct OrientationControlView: View {
    @Environment(ViewerState.self) private var viewerState
    @ObservedObject var viewModel: ViewerViewModel

    var body: some View {
        HStack {
            Text("Orientation")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Picker(
                "Orientation",
                selection: Binding<SliceOrientation>(
                    get: { viewerState.orientation },
                    set: { newValue in
                        viewModel.setOrientation(newValue)
                    }
                )
            ) {
                Text("AX").tag(SliceOrientation.axial)
                Text("COR").tag(SliceOrientation.coronal)
                Text("SAG").tag(SliceOrientation.sagittal)
            }
            .pickerStyle(.segmented)
        }
        .disabled(!viewerState.isImagingViewport(viewerState.clampedActiveIndex))
    }
}
