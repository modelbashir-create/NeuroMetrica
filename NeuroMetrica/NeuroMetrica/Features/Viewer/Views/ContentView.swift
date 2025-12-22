

import SwiftUI
import Observation

// MARK: - Root ContentView (Viewer Shell)

struct ContentView: View {
    // Shared viewer state is created in AppContainer and injected via `.environment(viewerState)`
    @Environment(ViewerState.self) private var viewerState
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @ObservedObject var viewModel: ViewerViewModel
    @ObservedObject var importViewModel: ImportViewModel
    @Binding var inspectorPresented: Bool

    // iOS 26: Namespaces for morphing sheet transitions
    @Namespace private var exportTransition
    @Namespace private var settingsTransition


    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(viewModel: importViewModel)
        } detail: {
            CanvasView(viewModel: viewModel, importViewModel: importViewModel)
                .navigationTitle("")
                #if os(iOS)
                .toolbar(.hidden, for: .navigationBar)
                #endif
        }
        // Inspector column (third pane)
        .inspector(isPresented: $inspectorPresented) {
            InspectorView(viewModel: viewModel)
                .environment(viewerState)
                .inspectorColumnWidth(min: 280, ideal: 320, max: 400)
        }
        .toolbar { toolbarContent }
        .toolbarRole(.editor)
        // iOS 26: Morphing sheet presentations
        .sheet(isPresented: .init(
            get: { viewerState.showExportSheet },
            set: { viewModel.setExportSheetPresented($0) }
        )) {
            ExportSheetView()
                .presentationDetents([.medium, .large])
                .applyMorphingTransition(id: "export", in: exportTransition)
        }
        .sheet(isPresented: .init(
            get: { viewerState.showSettingsSheet },
            set: { viewModel.setSettingsSheetPresented($0) }
        )) {
            NavigationStack {
                SettingsView()
            }
                .environment(viewerState)
                .presentationDetents([.medium, .large])
                .applyMorphingTransition(id: "settings", in: settingsTransition)
        }
        .focusable()
        .onKeyPress(.space) {
            viewModel.toggleCine(for: viewerState.clampedActiveIndex)
            return .handled
        }
        .onKeyPress(.upArrow) {
            viewModel.stepSlice(by: 1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            viewModel.stepSlice(by: -1)
            return .handled
        }
        .onKeyPress(.pageUp) {
            viewModel.stepSlice(by: 5)
            return .handled
        }
        .onKeyPress(.pageDown) {
            viewModel.stepSlice(by: -5)
            return .handled
        }
        .onKeyPress(.home) {
            viewModel.jumpToFirstSlice()
            return .handled
        }
        .onKeyPress(.end) {
            viewModel.jumpToLastSlice()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            viewModel.adjustCineFPS(by: -1, for: viewerState.clampedActiveIndex)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            viewModel.adjustCineFPS(by: 1, for: viewerState.clampedActiveIndex)
            return .handled
        }
    }

    // MARK: - Toolbar Content

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            viewModeMenu
            layoutMenu
        }

        // iOS 26: Flexible spacing with ToolbarSpacer
        ToolbarItemGroup(placement: .principal) {
            #if swift(>=6.0)
            if #available(iOS 26, macOS 26, *) {
                ToolbarSpacer(.flexible)
            }
            #endif

            viewerToolsGroup

            #if swift(>=6.0)
            if #available(iOS 26, macOS 26, *) {
                ToolbarSpacer(.flexible)
            }
            #endif
        }

        ToolbarItemGroup(placement: .primaryAction) {
            settingsButton
            inspectorToggle
            exportButton
        }
    }

    // MARK: - View Mode Menu

    private var viewModeMenu: some View {
        Menu {
            Button {
                viewModel.setViewerMode(.twoD)
            } label: {
                Label("2D", systemImage: viewerState.viewerMode == .twoD ? "checkmark" : "square")
            }

            Divider()

            ForEach(ThreeDSubMode.allCases) { mode in
                Button {
                    viewModel.setViewerMode(.threeD)
                    viewModel.setThreeDMode(mode)
                } label: {
                    Label(
                        mode.rawValue,
                        systemImage: viewerState.viewerMode == .threeD && viewerState.threeDMode == mode
                            ? "checkmark"
                            : "square"
                    )
                }
            }
        } label: {
            Image(systemName: viewerState.viewerMode == .twoD ? "cube" : "cube.fill")
        } primaryAction: {
            viewModel.toggleViewerMode()
        }
        .help("Toggle 2D/3D")
    }

    // MARK: - Layout Menu

    private var layoutMenu: some View {
        Menu {
            ForEach(LayoutMode.allCases) { mode in
                Button {
                    withAnimation(.smooth) {
                        viewModel.setLayout(mode)
                    }
                } label: {
                    Label(mode.rawValue, systemImage: layoutIcon(for: mode))
                }
            }
        } label: {
            layoutIconView
        } primaryAction: {
            withAnimation(.smooth) {
                viewModel.cycleLayout()
            }
        }
        .help("Cycle layout")
    }

    @ViewBuilder
    private var layoutIconView: some View {
        Group {
            switch viewerState.layoutMode {
            case .oneUp:
                Image(systemName: "rectangle")
            case .twoUp:
                Image(systemName: "rectangle.split.2x1")
            case .threeUp:
                Image(systemName: "rectangle.split.1x2.fill")
            case .fourUp:
                Image(systemName: "rectangle.split.2x2")
            }
        }
        .contentTransition(.symbolEffect(.automatic))
    }

    private func layoutIcon(for mode: LayoutMode) -> String {
        switch mode {
        case .oneUp:   return "rectangle"
        case .twoUp:   return "rectangle.split.2x1"
        case .threeUp: return "rectangle.split.1x2.fill"
        case .fourUp:  return "rectangle.split.2x2"
        }
    }

    // MARK: - Viewer Tools Group

    private var viewerToolsGroup: some View {
        ControlGroup {
            ForEach(ViewerTool.allCases) { tool in
                Button {
                    viewModel.setActiveTool(tool)
                } label: {
                    Image(systemName: tool.icon)
                }
                .help(tool.rawValue)
            }
        }
        .controlGroupStyle(.navigation)
        .disabled(viewerState.isLoadingVolume)
    }

    // MARK: - Primary Actions

    private var settingsButton: some View {
        Button {
            viewModel.setSettingsSheetPresented(true)
        } label: {
            Image(systemName: "gearshape")
        }
        .help("Settings")
        .applyTransitionSource(id: "settings", in: settingsTransition)
    }


    private var inspectorToggle: some View {
        Button {
            withAnimation(.smooth) {
                inspectorPresented.toggle()
            }
        } label: {
            Image(systemName: "sidebar.trailing")
        }
        .help("Toggle Inspector")
    }

    private var exportButton: some View {
        Button {
            viewModel.setExportSheetPresented(true)
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .help("Export")
        .applyTransitionSource(id: "export", in: exportTransition)
    }
}

// MARK: - iOS 26 Transition Helpers

extension View {
    @ViewBuilder
    func applyTransitionSource(id: String, in namespace: Namespace.ID) -> some View {
        #if swift(>=6.0)
        if #available(iOS 26, macOS 26, *) {
            self.matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
        #else
        self
        #endif
    }

    @ViewBuilder
    func applyMorphingTransition(id: String, in namespace: Namespace.ID) -> some View {
        #if swift(>=6.0)
        if #available(iOS 26, macOS 26, *) {
            self.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
        #else
        self
        #endif
    }
}

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
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
        }
        .fileImporter(
            isPresented: $viewModel.isFileImporterPresented,
            allowedContentTypes: FilePickerService.allowedContentTypes,
            allowsMultipleSelection: false
        ) { result in
            viewModel.handleFileImport(result: result)
        }
        .onChange(of: selectedSeriesID) { _, newValue in
            guard let seriesID = newValue else { return }
            let series = viewModel.studies
                .flatMap(\.series)
                .first(where: { $0.id == seriesID })
            guard let series else { return }
            let study = viewModel.studies.first(where: { $0.series.contains(series) })
            viewModel.openSeries(series, study: study)
        }
    }

    private var sidebarHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search studies", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))

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
                        .foregroundStyle(.red)
                        .help(errorMessage ?? "Unable to open study.")
                }

                Text(study.modality)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }

            HStack {
                Text(study.patientName)
                Text("•")
                Text(study.dateFormatted)
                Text("•")
                Text("\(study.series.count) series")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
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
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            }

            if showsError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .help(errorMessage ?? "Unable to open series.")
            }

            Text(series.modality)
                .font(.caption2)
                .fontWeight(.semibold)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: Capsule())
        }
        .padding(.vertical, 2)
        .padding(.leading, 8)
    }
}

// MARK: - Canvas View

struct CanvasView: View {
    @Environment(ViewerState.self) private var viewerState
    @ObservedObject var viewModel: ViewerViewModel
    @ObservedObject var importViewModel: ImportViewModel

    var body: some View {
        ZStack {
            // Heritage black canvas (required for diagnostic imaging)
            HeritagePACSTheme.canvasBackground
                .ignoresSafeArea()

            viewportLayout
        }
    }

    @ViewBuilder
    private var viewportLayout: some View {
        switch viewerState.layoutMode {
        case .oneUp:
            ViewportView(index: 0, viewModel: viewModel, importViewModel: importViewModel)
                .padding(4)

        case .twoUp:
            HStack(spacing: 2) {
                ViewportView(index: 0, viewModel: viewModel, importViewModel: importViewModel)
                ViewportView(index: 1, viewModel: viewModel, importViewModel: importViewModel)
            }
            .padding(4)

        case .threeUp:
            GeometryReader { proxy in
                VStack(spacing: 2) {
                    ViewportView(index: 0, viewModel: viewModel, importViewModel: importViewModel)
                        .frame(height: proxy.size.height * 0.6)

                    HStack(spacing: 2) {
                        ViewportView(index: 1, viewModel: viewModel, importViewModel: importViewModel)
                        ViewportView(index: 2, viewModel: viewModel, importViewModel: importViewModel)
                    }
                }
            }
            .padding(4)

        case .fourUp:
            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    ViewportView(index: 0, viewModel: viewModel, importViewModel: importViewModel)
                    ViewportView(index: 1, viewModel: viewModel, importViewModel: importViewModel)
                }
                HStack(spacing: 2) {
                    ViewportView(index: 2, viewModel: viewModel, importViewModel: importViewModel)
                    ViewportView(index: 3, viewModel: viewModel, importViewModel: importViewModel)
                }
            }
            .padding(4)
        }
    }
}

// MARK: - Individual Viewport (iOS 26 Liquid Glass)

struct ViewportView: View {
    @Environment(ViewerState.self) private var viewerState
    let index: Int
    @ObservedObject var viewModel: ViewerViewModel
    @ObservedObject var importViewModel: ImportViewModel

    private var isActive: Bool {
        index == viewerState.clampedActiveIndex
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                // Base viewport
                RoundedRectangle(cornerRadius: 8)
                    .fill(HeritagePACSTheme.viewportBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                HeritagePACSTheme.activeViewportBorder.opacity(isActive ? 0.7 : 0),
                                lineWidth: isActive ? 2.5 : 0
                            )
                    )

                if viewerState.isImagingViewport(index) {
                    ViewerView(
                        viewModel: viewModel,
                        image: viewModel.image(for: index),
                        isLoading: viewerState.isLoadingVolume,
                        isActive: index == viewerState.clampedActiveIndex
                    )
                } else {
                    Placeholder3DView()
                }

                // Crosshairs
                CrosshairOverlay(size: size)

                // Measurement annotation
                MeasurementOverlay(size: size)

                // iOS 26: Liquid Glass overlays
                viewportOverlays(size: size)

                if viewerState.isImagingViewport(index) {
                    viewportStateOverlays
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.setActiveViewportIndex(index)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Viewport \(index + 1)")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    @ViewBuilder
    private var viewportStateOverlays: some View {
        if viewerState.isLoadingVolume {
            LoadingOverlayView(title: viewerState.loadingTitle, detail: viewerState.loadingDetail)
        } else if let error = viewerState.lastError {
            ErrorOverlayView(
                title: error.title,
                message: error.message,
                canRetry: viewModel.canRetryLastLoad,
                onRetry: {
                    Task { await viewModel.retryLastLoad() }
                },
                onChooseAnother: {
                    importViewModel.openImporter()
                }
            )
        }
    }

    @ViewBuilder
    private func viewportOverlays(size: CGSize) -> some View {
        // iOS 26: Use GlassEffectContainer for grouped glass elements
        #if swift(>=6.0)
        if #available(iOS 26, macOS 26, *) {
            GlassEffectContainer {
                overlayContent(size: size)
            }
        } else {
            overlayContent(size: size)
        }
        #else
        overlayContent(size: size)
        #endif
    }

    @ViewBuilder
    private func overlayContent(size: CGSize) -> some View {
        // Center mode indicator
        modeIndicator

        // Corner overlays
        cornerOverlays
    }

    private var modeIndicator: some View {
        Group {
            if viewerState.viewerMode == .twoD {
                Text("2D")
                    .font(.caption.bold())
            } else {
                VStack(spacing: 2) {
                    Text("3D")
                        .font(.caption.bold())
                    Text(viewerState.threeDMode.rawValue)
                        .font(.caption2)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .applyGlassEffect(tint: .black.opacity(0.4))
    }

    private var cornerOverlays: some View {
        ZStack {
            // Top-left: Series info
            VStack(alignment: .leading, spacing: 2) {
                Text(viewerState.seriesTitle)
                    .font(.caption)
                    .foregroundStyle(HeritagePACSTheme.overlayTextPrimary)
                Text(viewerState.seriesSubtitle)
                    .font(.caption2)
                    .foregroundStyle(HeritagePACSTheme.overlayTextSecondary)
            }
            .padding(6)
            .applyGlassEffect(tint: .black.opacity(0.3))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(8)

            // Top-right: Patient info
            VStack(alignment: .trailing, spacing: 2) {
                Text(viewerState.patientDisplayName)
                    .font(.caption.bold())
                    .foregroundStyle(HeritagePACSTheme.phiHighlightYellow)
                Text(viewerState.patientDetails)
                    .font(.caption2)
                    .foregroundStyle(HeritagePACSTheme.overlayTextPrimary)
                Text(viewerState.acquisitionDateTimeDisplay)
                    .font(.caption2)
                    .foregroundStyle(HeritagePACSTheme.overlayTextSecondary)
            }
            .padding(6)
            .applyGlassEffect(tint: .black.opacity(0.3))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(8)

            // Bottom-left: Window/Level
            VStack(alignment: .leading, spacing: 2) {
                Text("W \(Int(viewerState.window))  L \(Int(viewerState.level))")
                    .font(.caption2.monospaced())
                Text("SLICE \(String(format: "%02d", viewerState.clampedSliceIndex + 1))/\(viewerState.seriesImagesDisplay)")
                    .font(.caption2.monospaced())
            }
            .foregroundStyle(HeritagePACSTheme.overlayTextSecondary)
            .padding(6)
            .applyGlassEffect(tint: .black.opacity(0.3))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(8)

            // Bottom-right: Status
            HStack(spacing: 6) {
                Circle()
                    .fill(HeritagePACSTheme.statusOK)
                    .frame(width: 6, height: 6)
                Text(viewerState.hasVolume ? "ONLINE" : "NO DATA")
                    .font(.caption2)
                    .foregroundStyle(HeritagePACSTheme.overlayTextSecondary)
            }
            .padding(6)
            .applyGlassEffect(tint: .black.opacity(0.3))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(8)
        }
    }

}

// iOS 26 Glass Effect Extension
extension View {
    @ViewBuilder
    func applyGlassEffect(tint: Color = .black.opacity(0.3), cornerRadius: CGFloat = 8) -> some View {
        #if swift(>=6.0)
        if #available(iOS 26, macOS 26, *) {
            self.glassEffect(.regular.tint(tint), in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(tint.opacity(0.5), in: RoundedRectangle(cornerRadius: cornerRadius))
        }
        #else
        self.background(tint.opacity(0.5), in: RoundedRectangle(cornerRadius: cornerRadius))
        #endif
    }
}

// MARK: - Overlays (Crosshair + Measurement)

struct CrosshairOverlay: View {
    let size: CGSize

    var body: some View {
        Canvas { context, _ in
            let midX = size.width / 2
            let midY = size.height / 2

            var path = Path()
            path.move(to: CGPoint(x: midX, y: 0))
            path.addLine(to: CGPoint(x: midX, y: size.height))
            path.move(to: CGPoint(x: 0, y: midY))
            path.addLine(to: CGPoint(x: size.width, y: midY))

            context.stroke(
                path,
                with: .color(HeritagePACSTheme.crosshairColor.opacity(0.5)),
                lineWidth: 1
            )
        }
    }
}

struct MeasurementOverlay: View {
    let size: CGSize

    var body: some View {
        Canvas { context, _ in
            var path = Path()
            path.move(to: CGPoint(x: size.width * 0.2, y: size.height * 0.75))
            path.addLine(to: CGPoint(x: size.width * 0.7, y: size.height * 0.35))

            context.stroke(
                path,
                with: .color(HeritagePACSTheme.measurementColor),
                style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
            )
        }
    }
}

struct Placeholder3DView: View {
    var body: some View {
        VStack(spacing: 6) {
            Text("3D view not available yet")
                .font(.caption.bold())
                .foregroundStyle(.white)
            Text("Coming soon")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct LoadingOverlayView: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(.circular)
            Text(title)
                .font(.callout.bold())
                .foregroundStyle(.white)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct ErrorOverlayView: View {
    let title: String
    let message: String
    let canRetry: Bool
    let onRetry: () -> Void
    let onChooseAnother: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.callout.bold())
                .foregroundStyle(.white)
            Text(message)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineLimit(3)

            HStack(spacing: 8) {
                Button("Try again", action: onRetry)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canRetry)

                Button("Choose another file…", action: onChooseAnother)
                    .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        )
    }
}

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
            Picker("Inspector Tab", selection: $selectedTab) {
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
                            .foregroundStyle(.secondary)
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
                    .foregroundStyle(.secondary)
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

// MARK: - Export Sheet (iOS 26 Liquid Glass)

struct ExportSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var exportFormat = "DICOM"
    @State private var anonymize = true
    @State private var includeAnnotations = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Format") {
                    Picker("Export Format", selection: $exportFormat) {
                        Text("DICOM").tag("DICOM")
                        Text("JPEG").tag("JPEG")
                        Text("PNG").tag("PNG")
                        Text("TIFF").tag("TIFF")
                    }
                }

                Section("Options") {
                    Toggle("Anonymize Patient Data", isOn: $anonymize)
                    Toggle("Include Annotations", isOn: $includeAnnotations)
                }

                Section {
                    Button {
                        // Export action
                        dismiss()
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Export")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
