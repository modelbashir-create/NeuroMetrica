import SwiftUI

struct WWLControlsView: View {
    @ObservedObject var viewModel: ViewerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // Window
            HStack {
                Text("Window")
                Spacer()
                Text("\(Int(viewModel.state.window))")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Slider(
                value: Binding(
                    get: { Double(viewModel.state.window) },
                    set: { newValue in
                        viewModel.setWindow(Float(newValue))
                    }
                ),
                in: 1...2000
            )

            // Level
            HStack {
                Text("Level")
                Spacer()
                Text("\(Int(viewModel.state.level))")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Slider(
                value: Binding(
                    get: { Double(viewModel.state.level) },
                    set: { newValue in
                        viewModel.setLevel(Float(newValue))
                    }
                ),
                in: -1000...1000
            )
        }
    }
}
