import SwiftUI

struct SliceNavigationView: View {
    @Environment(ViewerState.self) private var viewerState
    @ObservedObject var viewModel: ViewerViewModel

    var body: some View {
        let activeIndex = viewerState.clampedActiveIndex
        let sliceInfo = viewModel.sliceInfo(for: activeIndex)

        VStack(alignment: .leading, spacing: 8) {
            let sliceCount = sliceInfo?.sliceCount ?? 0
            let hasSlices = sliceCount > 0
            let hasSlider = sliceCount > 1
            let upper = hasSlider ? (sliceCount - 1) : 0
            let currentIndex = sliceInfo.map { min(max($0.displayIndex, 0), upper) } ?? 0

            HStack {
                Text(hasSlices ? "Slice \(currentIndex + 1) / \(sliceCount)" : "No slices")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }

            if hasSlider {
                Slider(
                    value: Binding(
                        get: { Double(currentIndex) },
                        set: { newValue in
                            let clamped = min(
                                max(Int(newValue.rounded()), 0),
                                upper
                            )
                            if clamped != currentIndex {
                                viewModel.setSliceIndex(clamped, for: activeIndex)
                            }
                        }
                    ),
                    in: 0...Double(upper),
                    step: 1
                )
                .accessibilityLabel("Slice")
                .accessibilityValue("\(currentIndex + 1) of \(sliceCount)")
            } else {
                Rectangle()
                    .opacity(0)
                    .frame(height: 24)
                    .accessibilityHidden(true)
            }
        }
        .disabled(!viewerState.isImagingViewport(activeIndex))
    }
}
