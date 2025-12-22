import Foundation
import SwiftUI

@MainActor
final class ImportViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var isFileImporterPresented: Bool = false

    private let filePickerService: FilePickerService
    private let recentFilesStore: RecentFilesStore
    private let viewerViewModel: ViewerViewModel

    init(
        filePickerService: FilePickerService,
        recentFilesStore: RecentFilesStore,
        viewerViewModel: ViewerViewModel
    ) {
        self.filePickerService = filePickerService
        self.recentFilesStore = recentFilesStore
        self.viewerViewModel = viewerViewModel
    }

    var studies: [Study] {
        recentFilesStore.studies
    }

    var filteredStudies: [Study] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return studies }

        let needle = trimmed.lowercased()
        return studies.filter { study in
            study.title.lowercased().contains(needle)
                || study.patientName.lowercased().contains(needle)
                || study.modality.lowercased().contains(needle)
                || study.accessionNumber.lowercased().contains(needle)
                || study.id.lowercased().contains(needle)
                || study.series.contains { series in
                    series.seriesDescription.lowercased().contains(needle)
                        || series.seriesNumber.lowercased().contains(needle)
                        || series.modality.lowercased().contains(needle)
                }
        }
    }

    var todayStudies: [Study] {
        filteredStudies.filter { $0.isToday }
    }

    var thisWeekStudies: [Study] {
        filteredStudies.filter { !$0.isToday && $0.isThisWeek }
    }

    var olderStudies: [Study] {
        filteredStudies.filter { !$0.isThisWeek }
    }

    func openImporter() {
        isFileImporterPresented = true
    }

    func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = filePickerService.normalizeSelection(urls) else { return }
            Task {
                await viewerViewModel.openVolume(from: url)
            }
        case .failure(let error):
            AppLogger.error("Import failed", error: error)
        }
    }

    func openStudy(_ study: Study) {
        Task {
            await viewerViewModel.openStudy(study)
        }
    }

    func openSeries(_ series: StudySeries, study: Study?) {
        Task {
            await viewerViewModel.openSeries(series, study: study)
        }
    }
}
