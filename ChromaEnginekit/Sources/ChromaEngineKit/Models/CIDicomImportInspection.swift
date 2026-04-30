import Foundation

public struct CIDicomSeriesSelection: Sendable, Equatable {
    public var seriesInstanceUID: String
    public var subseriesKey: String?

    public init(seriesInstanceUID: String, subseriesKey: String? = nil) {
        self.seriesInstanceUID = seriesInstanceUID
        self.subseriesKey = subseriesKey
    }
}

public struct CIDicomImportInspection: Sendable, Equatable {
    public var series: [CISeriesDiagnostic]
    public var subseries: [CISubseriesDiagnostic]
    public var selectedSeriesInfo: CISelectedSeriesInfo?
    public var selectionPolicy: String?

    public init(
        series: [CISeriesDiagnostic],
        subseries: [CISubseriesDiagnostic],
        selectedSeriesInfo: CISelectedSeriesInfo?,
        selectionPolicy: String? = nil
    ) {
        self.series = series
        self.subseries = subseries
        self.selectedSeriesInfo = selectedSeriesInfo
        self.selectionPolicy = selectionPolicy
    }
}
