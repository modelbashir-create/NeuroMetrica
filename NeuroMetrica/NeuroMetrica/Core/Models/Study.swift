import Foundation

/// Study record shown in the sidebar study browser.
struct Study: Identifiable, Hashable {
    let id: String
    let title: String
    let modality: String
    let date: Date
    let patientName: String
    let accessionNumber: String
    let seriesCount: Int
    let sourceURL: URL
    let series: [StudySeries]

    var dateFormatted: String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var isThisWeek: Bool {
        Calendar.current.isDate(date, equalTo: .now, toGranularity: .weekOfYear)
    }
}
