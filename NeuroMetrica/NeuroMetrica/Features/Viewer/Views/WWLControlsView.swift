import SwiftUI

/// WWLControlsView
///
/// Strict MVVM:
/// - Reads current window/level values from `ViewerViewModel`
/// - Mutates them only by calling `viewModel.setWindow(_:)` and `viewModel.setLevel(_:)`
/// - No use of `$viewModel` (which caused the dynamicMember / Binding errors).
struct WWLControlsView: View {
    @ObservedObject var viewModel: ViewerViewModel

    // MARK: - Bindings (Float in VM -> Double for Slider)

    private var windowBinding: Binding<Double> {
        Binding<Double>(
            get: { Double(viewModel.window) },
            set: { newValue in
                viewModel.setWindow(Float(newValue))
            }
        )
    }

    private var levelBinding: Binding<Double> {
        Binding<Double>(
            get: { Double(viewModel.level) },
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
                    Menu("Brain") {
                        Button("Brain (W 80 / L 40)") {
                            viewModel.setWindow(80)
                            viewModel.setLevel(40)
                        }
                        Button("Subdural (W 200 / L 80)") {
                            viewModel.setWindow(200)
                            viewModel.setLevel(80)
                        }
                        Button("Stroke (W 40 / L 40)") {
                            viewModel.setWindow(40)
                            viewModel.setLevel(40)
                        }
                        Button("Bone (W 2500 / L 500)") {
                            viewModel.setWindow(2500)
                            viewModel.setLevel(500)
                        }
                    }
                }

                // Window slider
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Window")
                        Spacer()
                        Text("\(Int(viewModel.window))")
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
                        Text("\(Int(viewModel.level))")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: levelBinding, in: -1024...3072)
                }
            }
        }
    }
}

