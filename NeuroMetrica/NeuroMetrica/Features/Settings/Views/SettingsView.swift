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
                Toggle("Enable Debug Overlay", isOn: $viewModel.settings.showDebugOverlay)
                Toggle("Show PHI in Metadata", isOn: $viewModel.settings.showPHIInDiagnostics)
                    .disabled(!viewModel.settings.showDebugOverlay)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("WW/WL Level Scale")
                        Spacer()
                        Text("\(viewModel.settings.windowLevelDragLevelScale, specifier: "%.4f")")
                            .foregroundColor(.secondary)
                    }
                    Slider(
                        value: $viewModel.settings.windowLevelDragLevelScale,
                        in: 0.0005...0.02,
                        step: 0.0005
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("WW/WL Window/Level Ratio")
                        Spacer()
                        Text("\(viewModel.settings.windowLevelDragWindowToLevelRatio, specifier: "%.2f")")
                            .foregroundColor(.secondary)
                    }
                    Slider(
                        value: $viewModel.settings.windowLevelDragWindowToLevelRatio,
                        in: 0.2...1.0,
                        step: 0.05
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("WW/WL Axis Lock Threshold")
                        Spacer()
                        Text("\(viewModel.settings.windowLevelDragAxisLockThreshold, specifier: "%.2f")")
                            .foregroundColor(.secondary)
                    }
                    Slider(
                        value: $viewModel.settings.windowLevelDragAxisLockThreshold,
                        in: 0.05...1.0,
                        step: 0.05
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("WW/WL Response Gamma")
                        Spacer()
                        Text("\(viewModel.settings.windowLevelDragResponseGamma, specifier: "%.2f")")
                            .foregroundColor(.secondary)
                    }
                    Slider(
                        value: $viewModel.settings.windowLevelDragResponseGamma,
                        in: 1.0...1.5,
                        step: 0.05
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("WW/WL Dead Zone")
                        Spacer()
                        Text("\(viewModel.settings.windowLevelDragDeadZonePoints, specifier: "%.1f") pts")
                            .foregroundColor(.secondary)
                    }
                    Slider(
                        value: $viewModel.settings.windowLevelDragDeadZonePoints,
                        in: 0.0...8.0,
                        step: 0.5
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("WW/WL Preset Snap Tolerance")
                        Spacer()
                        Text("\(Int(viewModel.settings.windowLevelPresetSnapTolerance * 100))%")
                            .foregroundColor(.secondary)
                    }
                    Slider(
                        value: $viewModel.settings.windowLevelPresetSnapTolerance,
                        in: 0.02...0.2,
                        step: 0.01
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("WW/WL Preset Snap Strength")
                        Spacer()
                        Text("\(viewModel.settings.windowLevelPresetSnapStrength, specifier: "%.2f")")
                            .foregroundColor(.secondary)
                    }
                    Slider(
                        value: $viewModel.settings.windowLevelPresetSnapStrength,
                        in: 0.0...1.0,
                        step: 0.05
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("WW/WL Option Fine Scale")
                        Spacer()
                        Text("\(viewModel.settings.windowLevelDragFineAdjustmentScale, specifier: "%.2f")x")
                            .foregroundColor(.secondary)
                    }
                    Slider(
                        value: $viewModel.settings.windowLevelDragFineAdjustmentScale,
                        in: 0.1...0.5,
                        step: 0.05
                    )
                }

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
