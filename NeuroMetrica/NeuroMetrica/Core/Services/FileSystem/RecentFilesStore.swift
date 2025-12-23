import Foundation
import Combine

@MainActor
final class RecentFilesStore: ObservableObject {
    @Published private(set) var studies: [Study] = []

    func upsertStudy(_ study: Study) {
        if let index = studies.firstIndex(where: { $0.id == study.id }) {
            studies[index] = study
        } else {
            studies.insert(study, at: 0)
        }
    }

    func study(withID id: String?) -> Study? {
        guard let id else { return nil }
        return studies.first { $0.id == id }
    }
}
