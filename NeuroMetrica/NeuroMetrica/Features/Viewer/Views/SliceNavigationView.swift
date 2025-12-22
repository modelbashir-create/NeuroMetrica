import SwiftUI

struct SliceNavigationView: View {
    @Environment(ViewerState.self) private var viewerState
    @ObservedObject var viewModel: ViewerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Snapshot values — avoid constructing controls that assert on empty ranges
            let sliceCount = viewerState.sliceCount
            let hasSlices = sliceCount > 0
            let upper = hasSlices ? (sliceCount - 1) : 0
            let currentIndex = hasSlices
                ? min(max(viewerState.sliceIndex, 0), upper)
                : 0

            // Label: "Slice X / N" or "No slices"
            HStack {
                Text(hasSlices ? "Slice \(currentIndex + 1) / \(sliceCount)" : "No slices")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }

            // Only construct a Slider when there are slices — some SwiftUI slider variants
            // assert if the range/content is degenerate.
            if hasSlices {
                Slider(
                    value: Binding(
                        get: { Double(currentIndex) },
                        set: { newValue in
                            let clamped = min(
                                max(Int(newValue.rounded()), 0),
                                upper
                            )
                            if clamped != viewerState.sliceIndex {
                                viewModel.setSliceIndex(clamped)
                            }
                        }
                    ),
                    in: 0...Double(upper),
                    step: 1
                )
                .accessibilityLabel("Slice")
                .accessibilityValue("\(currentIndex + 1) of \(sliceCount)")
            } else {
                // Invisible spacer to keep layout consistent without creating a Slider when empty
                Rectangle()
                    .opacity(0)
                    .frame(height: 24)
                    .accessibilityHidden(true)
            }
        }
        .disabled(!viewerState.isImagingViewport(viewerState.clampedActiveIndex))
    }
}
