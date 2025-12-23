import SwiftUI

// MARK: - Export Sheet (iOS 26 Liquid Glass)

struct ExportSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var exportFormat = "DICOM"
    @State private var anonymize = true
    @State private var includeAnnotations = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Format") {
                    Picker("Export Format", selection: $exportFormat) {
                        Text("DICOM").tag("DICOM")
                        Text("JPEG").tag("JPEG")
                        Text("PNG").tag("PNG")
                        Text("TIFF").tag("TIFF")
                    }
                }

                Section("Options") {
                    Toggle("Anonymize Patient Data", isOn: $anonymize)
                    Toggle("Include Annotations", isOn: $includeAnnotations)
                }

                Section {
                    Button {
                        // Export action
                        dismiss()
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Export")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
