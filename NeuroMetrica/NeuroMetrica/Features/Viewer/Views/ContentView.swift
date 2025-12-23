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
        .accessibilityIdentifier("ViewerContentView")
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
                    Label {
                        Text(mode.rawValue)
                    } icon: {
                        layoutIconImage(for: mode)
                    }
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
        layoutIconImage(for: viewerState.layoutMode)
        .contentTransition(.symbolEffect(.automatic))
    }

    @ViewBuilder
    private func layoutIconImage(for mode: LayoutMode) -> some View {
        switch mode {
        case .threeUp:
            Image("3upicon")
        default:
            Image(systemName: layoutIcon(for: mode))
        }
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
