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
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppSettings())
}
