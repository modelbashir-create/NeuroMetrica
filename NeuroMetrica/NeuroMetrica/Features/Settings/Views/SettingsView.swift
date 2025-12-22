import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appSettings: AppSettings

    var body: some View {
        Form {
            Section(header: Text("Processing")) {
                Picker("Processing Backend", selection: $appSettings.processingBackend) {
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
                Picker("DICOM Backend", selection: $appSettings.dicomBackendPreference) {
                    ForEach(DicomBackendPreference.allCases) { backend in
                        Text(backend.displayName).tag(backend)
                    }
                }

                Text("DCMTK is preferred when available; GDCM is the fallback.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppSettings())
}
