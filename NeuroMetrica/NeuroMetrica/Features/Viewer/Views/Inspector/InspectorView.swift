import SwiftUI
import ChromaEngineKit

// MARK: - Inspector View (iOS 26 Design)

struct InspectorView: View {
    @Environment(ViewerState.self) private var viewerState
    @State private var selectedTab: InspectorTab = .display
    @ObservedObject var viewModel: ViewerViewModel

    enum InspectorTab: String, CaseIterable {
        case display = "Display"
        case measurements = "Measurements"
        case analysis = "Analysis"
    }

    var body: some View {
        VStack(spacing: 0) {
            // iOS 26: Segmented control adopts glass automatically
            Picker("", selection: $selectedTab) {
                ForEach(InspectorTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue)
                        .lineLimit(1)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedTab {
                    case .display:
                        DisplayTabContent(viewModel: viewModel)
                    case .measurements:
                        MeasurementsTabContent()
                    case .analysis:
                        AnalysisTabContent(viewModel: viewModel)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        #if os(iOS)
        .navigationTitle("Inspector")
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Inspector Tabs

struct DisplayTabContent: View {
    @Environment(ViewerState.self) private var viewerState
    @ObservedObject var viewModel: ViewerViewModel
    @State private var linkViewports = true
    @State private var lockZoom = false
    @State private var showCrosshair = true
    @State private var showPatientInfo = true

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Layout section
            GroupBox("Layout") {
                VStack(alignment: .leading, spacing: 12) {
                    LabeledContent("Current Layout") {
                        Text(viewerState.layoutMode.rawValue)
                    }

                    Toggle("Link Viewports", isOn: $linkViewports)
                    Toggle("Lock Zoom", isOn: $lockZoom)
                }
            }

            GroupBox("Orientation") {
                OrientationControlView(viewModel: viewModel)
                    .disabled(viewerState.isLoadingVolume)
            }

            GroupBox("Slice Navigation") {
                SliceNavigationView(viewModel: viewModel)
                    .disabled(viewerState.isLoadingVolume)
            }

            WWLControlsView(viewModel: viewModel)
                .disabled(viewerState.isLoadingVolume)

            GroupBox("Loaded Metadata") {
                MetadataSummarySection()
            }

            GroupBox("Metadata Status") {
                MetadataStatusSection(viewModel: viewModel)
            }

            GroupBox("Image Data Status") {
                ImageDataStatusSection(viewModel: viewModel)
            }

            // Overlays section
            GroupBox("Overlays") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Crosshair", isOn: $showCrosshair)
                    Toggle("Patient Info", isOn: $showPatientInfo)
                }
            }
        }
    }
}

struct MetadataStatusSection: View {
    @ObservedObject var viewModel: ViewerViewModel

    var body: some View {
        if let report = viewModel.metadataReport() {
            VStack(alignment: .leading, spacing: 10) {
                statusGroup(title: "Identity", entries: report.identity)
                statusGroup(title: "Geometry", entries: report.geometry)
            }
        } else {
            Text("No metadata loaded")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func statusGroup(title: String, entries: [MetadataChecklistEntry]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            ForEach(entries) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(entry.label)
                        Spacer()
                        Text(entry.status.rawValue.uppercased())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let detail = entry.detail, !detail.isEmpty {
                        Text(detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct MetadataSummarySection: View {
    @Environment(ViewerState.self) private var viewerState

    var body: some View {
        if hasMetadataSummary {
            VStack(alignment: .leading, spacing: 10) {
                metadataRow("Series", currentSeries)
                metadataRow("Study", currentStudy)
                metadataRow("Patient", viewerState.patientDisplayName)
                metadataRow("Patient Details", viewerState.patientDetails)
                metadataRow("Modality", currentModality)
                metadataRow("Acquired", viewerState.acquisitionDateTimeDisplay)
                metadataRow("Series UID", viewerState.metadata?.seriesInstanceUID ?? "—")
                metadataRow("Study UID", viewerState.metadata?.studyInstanceUID ?? "—")
            }
        } else {
            Text("No metadata loaded")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var hasMetadataSummary: Bool {
        viewerState.metadata != nil
            || viewerState.activeSeries != nil
            || !(viewerState.currentSeriesLabel?.isEmpty ?? true)
            || !(viewerState.currentStudyLabel?.isEmpty ?? true)
    }

    private var currentSeries: String {
        if let label = viewerState.currentSeriesLabel, !label.isEmpty {
            return label
        }
        return viewerState.seriesTitle
    }

    private var currentStudy: String {
        if let label = viewerState.currentStudyLabel, !label.isEmpty {
            return label
        }
        if let study = viewerState.metadata?.studyDescription, !study.isEmpty {
            return study
        }
        return "—"
    }

    private var currentModality: String {
        if let modality = viewerState.metadata?.modality, !modality.isEmpty {
            return modality
        }
        if let modality = viewerState.activeSeries?.modality, !modality.isEmpty {
            return modality
        }
        return "—"
    }

    @ViewBuilder
    private func metadataRow(_ label: String, _ value: String) -> some View {
        LabeledContent(label) {
            Text(value.isEmpty ? "—" : value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.primary)
        }
    }
}

struct ImageDataStatusSection: View {
    @ObservedObject var viewModel: ViewerViewModel
    @EnvironmentObject private var appSettings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let report = viewModel.imageDataReport() {
                statusGroup(title: "Pixel Data", entries: report.pixelData)
                statusGroup(title: "Encoding", entries: report.encoding)
                statusGroup(title: "Scaling", entries: report.scaling)
                statusGroup(title: "Transfer Syntax", entries: report.transferSyntax)
                statusGroup(title: "Consistency", entries: report.consistency)
                statusGroup(title: "Geometry", entries: report.geometry)
                statusGroup(title: "Rendering", entries: report.rendering)

                if let stats = report.volumeStats {
                    Text("Volume Range: \(format(stats.range.min)) … \(format(stats.range.max))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if appSettings.showDebugOverlay && !report.sliceStats.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Slice Ranges")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                        ForEach(report.sliceStats) { stats in
                            Text("Slice \(stats.index + 1): \(format(stats.range.min)) … \(format(stats.range.max))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                Text("No image data loaded")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func statusGroup(title: String, entries: [ImageDataChecklistEntry]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            ForEach(entries) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(entry.label)
                        Spacer()
                        Text(entry.status.rawValue.uppercased())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let detail = entry.detail, !detail.isEmpty {
                        Text(detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func format(_ value: Double) -> String {
        var text = String(format: "%.4f", value)
        while text.contains(".") && text.last == "0" {
            text.removeLast()
        }
        if text.last == "." {
            text.removeLast()
        }
        return text
    }
}

struct MeasurementsTabContent: View {
    @State private var showMeasurements = true
    @State private var measurementUnits = "mm"
    @State private var distanceTool = true
    @State private var angleTool = false
    @State private var areaTool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Toggle("Show Measurements", isOn: $showMeasurements)

            GroupBox("Measurement Style") {
                Picker("Units", selection: $measurementUnits) {
                    Text("mm").tag("mm")
                    Text("cm").tag("cm")
                    Text("in").tag("in")
                }
            }

            GroupBox("Tools") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Distance", isOn: $distanceTool)
                    Toggle("Angle", isOn: $angleTool)
                    Toggle("Area", isOn: $areaTool)
                }
            }

            GroupBox("Recorded") {
                Text("No measurements recorded")
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct AnalysisTabContent: View {
    @Environment(ViewerState.self) private var viewerState
    @ObservedObject var viewModel: ViewerViewModel
    @State private var enableShading = true
    @State private var showClippingPlanes = false
    @State private var aiModel = "segmentation"
    @State private var aiOverlay = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 3D Mode section
            GroupBox("3D Rendering") {
                VStack(alignment: .leading, spacing: 12) {
                    Picker(
                        "Mode",
                        selection: Binding(
                            get: { viewerState.threeDMode },
                            set: { viewModel.setThreeDMode($0) }
                        )
                    ) {
                        ForEach(ThreeDSubMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(viewerState.viewerMode == .twoD)

                    Toggle("Enable Shading", isOn: $enableShading)
                        .disabled(viewerState.viewerMode == .twoD)
                    Toggle("Clipping Planes", isOn: $showClippingPlanes)
                        .disabled(viewerState.viewerMode == .twoD)
                }
            }

            // Export section
            GroupBox("Export") {
                VStack(spacing: 10) {
                    Button {
                        // Snapshot action
                    } label: {
                        Label("Snapshot Viewport", systemImage: "camera")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        // Export action
                    } label: {
                        Label("Export Anonymized", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                }
            }

            // AI section
            GroupBox("AI Features") {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Model", selection: $aiModel) {
                        Text("Segmentation").tag("segmentation")
                        Text("Detection").tag("detection")
                        Text("Classification").tag("classification")
                    }

                    Toggle("AI Overlay", isOn: $aiOverlay)
                }
            }
        }
    }
}
