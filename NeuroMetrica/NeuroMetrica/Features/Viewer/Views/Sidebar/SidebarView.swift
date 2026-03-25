import SwiftUI

// MARK: - Sidebar View

struct SidebarView: View {
    @SceneStorage("selectedStudyID") private var selectedStudyID: String?
    @SceneStorage("selectedSeriesID") private var selectedSeriesID: String?
    @State private var expandedStudyIDs: Set<String> = []
    @Environment(ViewerState.self) private var viewerState
    @ObservedObject var viewModel: ImportViewModel

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader

            List(selection: $selectedSeriesID) {
                if !viewModel.todayStudies.isEmpty {
                    Section("Today") {
                        ForEach(viewModel.todayStudies) { study in
                            studySection(for: study)
                        }
                    }
                }

                if !viewModel.thisWeekStudies.isEmpty {
                    Section("This Week") {
                        ForEach(viewModel.thisWeekStudies) { study in
                            studySection(for: study)
                        }
                    }
                }

                if !viewModel.olderStudies.isEmpty {
                    Section("Earlier") {
                        ForEach(viewModel.olderStudies) { study in
                            studySection(for: study)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Studies")
            .modifier(SidebarSearchModifier(searchText: $viewModel.searchText))
            .onDrop(of: viewModel.allowedContentTypes, isTargeted: nil) { providers in
                handleSidebarDrop(providers: providers)
            }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }
    .fileImporter(
        isPresented: $viewModel.isFileImporterPresented,
        allowedContentTypes: viewModel.allowedContentTypes,
        allowsMultipleSelection: true
    ) { result in
        viewModel.handleFileImport(result: result)
    }
        .onChange(of: selectedSeriesID) { _, newValue in
            guard let seriesID = newValue else { return }
            guard seriesID != viewerState.activeSeries?.id else { return }
            let series = viewModel.studies
                .flatMap(\.series)
                .first(where: { $0.id == seriesID })
            guard let series else { return }
            let study = viewModel.studies.first(where: { $0.series.contains(series) })
            viewModel.openSeries(series, study: study)
        }
        .onChange(of: viewerState.activeSeries?.id) { _, newValue in
            guard let seriesID = newValue else { return }
            selectedSeriesID = seriesID
            if let study = viewModel.studies.first(where: { $0.series.contains(where: { $0.id == seriesID }) }) {
                selectedStudyID = study.id
            }
        }
    }

    private var sidebarHeader: some View {
        VStack(spacing: 8) {
            Button {
                viewModel.openImporter()
            } label: {
                Label("Open Volume…", systemImage: "folder")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
        }
        .padding([.horizontal, .top], 12)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func studySection(for study: Study) -> some View {
        let isExpanded = expandedStudyIDs.contains(study.id)
        DisclosureGroup(
            isExpanded: Binding(
                get: { isExpanded },
                set: { expanded in
                    if expanded {
                        expandedStudyIDs.insert(study.id)
                    } else {
                        expandedStudyIDs.remove(study.id)
                    }
                }
            )
        ) {
            ForEach(study.series) { series in
                SeriesRow(
                    series: series,
                    isLoading: viewerState.loadingSeriesID == series.id,
                    showsError: viewerState.errorSeriesID == series.id,
                    errorMessage: viewerState.lastError?.message
                )
                    .tag(series.id)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedStudyID = study.id
                        selectedSeriesID = series.id
                    }
            }
        } label: {
            StudyRow(
                study: study,
                isLoading: viewerState.loadingStudyID == study.id,
                showsError: viewerState.errorStudyID == study.id,
                errorMessage: viewerState.lastError?.message
            )
        }
    }

    // Sidebar drop handler: routes dropped URLs through ImportViewModel's existing import/open flow.
    private func handleSidebarDrop(providers: [NSItemProvider]) -> Bool {
        viewModel.handleDroppedProviders(providers)
    }
}

private struct SidebarSearchModifier: ViewModifier {
    @Binding var searchText: String

    func body(content: Content) -> some View {
        #if os(macOS)
        content.searchable(text: $searchText, placement: .sidebar, prompt: "Search studies")
        #else
        content.searchable(text: $searchText, placement: .navigationBarDrawer, prompt: "Search studies")
        #endif
    }
}

struct StudyRow: View {
    let study: Study
    let isLoading: Bool
    let showsError: Bool
    let errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(study.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer()

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }

                if showsError {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .help(errorMessage ?? "Unable to open study.")
                }

                Text(study.modality)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
            }

            HStack {
                Text(study.patientName)
                Text("•")
                Text(study.dateFormatted)
                Text("•")
                Text("\(study.series.count) series")
            }
            .font(.caption)
            .lineLimit(1)
        }
        .padding(.vertical, 2)
    }
}

struct SeriesRow: View {
    let series: StudySeries
    let isLoading: Bool
    let showsError: Bool
    let errorMessage: String?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(series.seriesDescription)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(isLoading ? "Loading…" : "SER \(series.seriesNumber) • \(series.imagesCount) images")
                    .font(.caption2)
            }

            Spacer()

            if isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            }

            if showsError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .help(errorMessage ?? "Unable to open series.")
            }

            Text(series.modality)
                .font(.caption2)
                .fontWeight(.semibold)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
        }
        .padding(.vertical, 2)
        .padding(.leading, 8)
    }
}
