import Foundation

@MainActor
protocol VolumeOpenRouting {
    func openVolume(from url: URL) async
    func openVolumes(from urls: [URL]) async
    func openStudy(_ study: Study) async
    func openSeries(_ series: StudySeries, study: Study?) async
}
