import Foundation

/// Series record shown under a Study in the sidebar.
struct StudySeries: Identifiable, Hashable {
    let id: String
    let seriesDescription: String
    let seriesNumber: String
    let modality: String
    let imagesCount: Int
    let sourceURL: URL
}
