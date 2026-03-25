import SwiftUI

/// Lightweight import view for feature-level usage and previews.
struct ImportView: View {
    @ObservedObject var viewModel: ImportViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                viewModel.openImporter()
            } label: {
                Label("Open Volume…", systemImage: "folder")
            }
            .buttonStyle(.borderedProminent)

            if viewModel.studies.isEmpty {
                Text("No recent studies")
                    .foregroundStyle(.secondary)
            } else {
                List(viewModel.studies) { study in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(study.title)
                            .font(.headline)
                        Text(study.patientName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(minHeight: 200)
            }
        }
        .padding()
        .fileImporter(
            isPresented: $viewModel.isFileImporterPresented,
            allowedContentTypes: viewModel.allowedContentTypes,
            allowsMultipleSelection: true
        ) { result in
            viewModel.handleFileImport(result: result)
        }
    }
}
