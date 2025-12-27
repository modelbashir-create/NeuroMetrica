import SwiftUI

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
