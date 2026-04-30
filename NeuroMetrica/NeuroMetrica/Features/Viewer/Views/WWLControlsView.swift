import SwiftUI

/// WWLControlsView
///
/// Strict MVVM:
/// - Reads current window/level values from `ViewerViewModel`
/// - Mutates them only by calling `viewModel.setWindow(_:)` and `viewModel.setLevel(_:)`
/// - No use of `$viewModel` (which caused the dynamicMember / Binding errors).
struct WWLControlsView: View {
    @Environment(ViewerState.self) private var viewerState
    @ObservedObject var viewModel: ViewerViewModel

    // MARK: - Bindings (Float in VM -> Double for Slider)

    private var windowBinding: Binding<Double> {
        Binding<Double>(
            get: { Double(viewerState.window) },
            set: { newValue in
                viewModel.setWindow(Float(newValue))
            }
        )
    }

    private var levelBinding: Binding<Double> {
        Binding<Double>(
            get: { Double(viewerState.level) },
            set: { newValue in
                viewModel.setLevel(Float(newValue))
            }
        )
    }

    // MARK: - Body

    var body: some View {
        GroupBox("Window / Level") {
            VStack(alignment: .leading, spacing: 12) {

                // Presets
                HStack {
                    Text("Preset")
                    Spacer()
                    Menu("Presets") {
                        ForEach(viewModel.windowLevelPresetSections()) { section in
                            Section(section.title) {
                                ForEach(section.presets) { preset in
                                    Button(preset.menuLabel) {
                                        viewModel.applyWindowLevelPreset(preset)
                                    }
                                }
                            }
                        }
                    }
                }

                // Window slider
                VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Window")
                            Spacer()
                            Text("\(Int(viewerState.window))")
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: windowBinding, in: 1...4096)
                    }

                // Level slider
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Level")
                            Spacer()
                            Text("\(Int(viewerState.level))")
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                    Slider(value: levelBinding, in: -1024...3072)
                }
            }
        }
        .disabled(!viewerState.isImagingViewport(viewerState.clampedActiveIndex))
    }
}
