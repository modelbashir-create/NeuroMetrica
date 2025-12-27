import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section(header: Text("Processing")) {
                Picker("Processing Backend", selection: $viewModel.settings.processingBackend) {
                    ForEach(ProcessingBackend.allCases) { backend in
                        Text(backend.displayName).tag(backend)
                    }
                }
                .pickerStyle(.segmented)

                Text("GPU runs Metal-based slicing and window/level. CPU uses the reference pipeline.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("DICOM")) {
                Picker("DICOM Backend", selection: $viewModel.settings.dicomBackendPreference) {
                    ForEach(DicomBackendPreference.allCases) { backend in
                        Text(backend.displayName).tag(backend)
                    }
                }

                Text("DCMTK is preferred when available; GDCM is the fallback.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("Developer Tools")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Slice Scroll Sensitivity")
                        Spacer()
                        Text("\(Int(viewModel.settings.sliceScrollBaseThreshold)) pts / slice")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $viewModel.settings.sliceScrollBaseThreshold, in: 20...80, step: 1)
                }

                Stepper(
                    "Fast Scroll Multiplier: \(viewModel.settings.sliceScrollFastMultiplier)x",
                    value: $viewModel.settings.sliceScrollFastMultiplier,
                    in: 2...6
                )

                Stepper(
                    "Max Slices per Scroll: \(viewModel.settings.sliceScrollMaxSlicesPerEvent)",
                    value: $viewModel.settings.sliceScrollMaxSlicesPerEvent,
                    in: 2...12
                )

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Scroll Momentum")
                        Spacer()
                        Text("\(Int(viewModel.settings.sliceScrollMomentumScale * 100))%")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $viewModel.settings.sliceScrollMomentumScale, in: 0.01...1.0, step: 0.05)
                }

                Stepper(
                    "Page Jump Size: \(viewModel.settings.sliceScrollPageJumpSize)",
                    value: $viewModel.settings.sliceScrollPageJumpSize,
                    in: 5...30
                )

                Toggle("Use Shift for Fast Scroll", isOn: $viewModel.settings.sliceScrollUseShiftFastMode)

                Button("Reset Scroll Tuning to Defaults") {
                    viewModel.resetScrollTuningToDefaults()
                }
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    SettingsView(viewModel: SettingsViewModel(settings: AppSettings()))
}
