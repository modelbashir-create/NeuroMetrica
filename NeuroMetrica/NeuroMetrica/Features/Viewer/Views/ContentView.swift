import SwiftUI
import Observation

#if os(macOS)
import AppKit
#endif

// MARK: - Root ContentView (Viewer Shell)

struct ContentView: View {

    @Environment(ViewerState.self) private var viewerState
    @EnvironmentObject private var appSettings: AppSettings

    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    @ObservedObject var viewModel: ViewerViewModel
    @ObservedObject var importViewModel: ImportViewModel
    @ObservedObject var settingsViewModel: SettingsViewModel

    @Binding var inspectorPresented: Bool

    @Namespace private var exportTransition
    @Namespace private var settingsTransition

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {

            SidebarView(viewModel: importViewModel)

        } detail: {

            CanvasView(
                viewModel: viewModel,
                importViewModel: importViewModel
            )
            .navigationTitle("")
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
        }
        .accessibilityIdentifier("ViewerContentView")

        // MARK: Inspector

        .inspector(isPresented: $inspectorPresented) {
            InspectorView(viewModel: viewModel)
                .environment(viewerState)
                .inspectorColumnWidth(min: 280, ideal: 320, max: 400)
        }

        // MARK: Toolbar

        .toolbar { toolbarContent }
        .toolbarRole(.editor)

        // MARK: Export Sheet

        .sheet(
            isPresented: .init(
                get: { viewerState.showExportSheet },
                set: { viewModel.setExportSheetPresented($0) }
            )
        ) {
            ExportSheetView()
                .presentationDetents([.medium, .large])
                .applyMorphingTransition(id: "export", in: exportTransition)
        }

        // MARK: Settings Sheet

        .sheet(
            isPresented: .init(
                get: { viewerState.showSettingsSheet },
                set: { viewModel.setSettingsSheetPresented($0) }
            )
        ) {
            NavigationStack {
                SettingsView(viewModel: settingsViewModel)
            }
            .environment(viewerState)
            .presentationDetents([.medium, .large])
            .applyMorphingTransition(id: "settings", in: settingsTransition)
        }

        // MARK: Keyboard Handling

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
            viewModel.stepSlice(by: appSettings.sliceScrollPageJumpSize)
            return .handled
        }
        .onKeyPress(.pageDown) {
            viewModel.stepSlice(by: -appSettings.sliceScrollPageJumpSize)
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

        #if os(macOS)
        .background(
            KeyDownCatcherView(onKeyDown: handleKeyDown)
                .frame(width: 0, height: 0)
        )
        #endif
        .background(fitToViewKeyCommand)
    }

    // MARK: - macOS Option Paging

    #if os(macOS)
    private func handleKeyDown(_ event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.option) else { return false }

        switch event.keyCode {
        case 126: // Up
            viewModel.stepSlice(by: appSettings.sliceScrollPageJumpSize)
            return true
        case 125: // Down
            viewModel.stepSlice(by: -appSettings.sliceScrollPageJumpSize)
            return true
        default:
            return false
        }
    }

    private struct KeyDownCatcherView: NSViewRepresentable {

        var onKeyDown: (NSEvent) -> Bool

        final class RepresentedView: NSView {
            var onKeyDown: ((NSEvent) -> Bool)?
            override var acceptsFirstResponder: Bool { true }

            override func keyDown(with event: NSEvent) {
                if onKeyDown?(event) == true { return }
                super.keyDown(with: event)
            }
        }

        func makeNSView(context: Context) -> RepresentedView {
            let view = RepresentedView()
            view.onKeyDown = onKeyDown
            DispatchQueue.main.async {
                view.window?.makeFirstResponder(view)
            }
            return view
        }

        func updateNSView(_ nsView: RepresentedView, context: Context) {
            nsView.onKeyDown = onKeyDown
        }
    }
    #endif

    private var fitToViewKeyCommand: some View {
        Button("") {
            viewModel.zoomFitActiveView()
        }
        #if os(macOS)
        .keyboardShortcut("0", modifiers: [.command])
        #else
        .keyboardShortcut("0", modifiers: [.control])
        #endif
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    // MARK: - Toolbar Content

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {

        ToolbarItemGroup(placement: .navigation) {
            viewModeMenu
            if viewerState.viewerMode == .mpr {
                mprLayoutMenu
            } else {
                layoutMenu
            }
        }

        ToolbarItemGroup(placement: .principal) {

            viewerToolsGroup
            resetViewButton
        }

        ToolbarItemGroup(placement: .primaryAction) {
            settingsButton
            inspectorToggle
            exportButton
        }
    }

    // MARK: - View Mode Menu (RESTORED)

    private var viewModeMenu: some View {
        Menu {
            Button {
                viewModel.selectTwoDMode()
            } label: {
                menuItemLabel(title: "2D", isActive: viewerState.viewerMode == .twoD)
            }

            Divider()

            ForEach(ThreeDSubMode.allCases) { mode in
                Button {
                    viewModel.selectReformatMode(mode)
                } label: {
                    menuItemLabel(title: mode.rawValue, isActive: isReformatModeActive(mode))
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: viewerState.viewerMode == .twoD ? "cube" : "cube.fill")
                Text(viewModeLabelText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } primaryAction: {
            viewModel.enterReformatModeIfNeeded()
        }
        .help("Toggle 2D / 3D")
    }

    private var viewModeLabelText: String {
        switch viewerState.viewerMode {
        case .twoD:
            return "2D"
        case .mpr:
            return "MPR"
        case .threeD:
            return viewerState.threeDMode.rawValue
        }
    }

    private func isReformatModeActive(_ mode: ThreeDSubMode) -> Bool {
        if mode == .mpr {
            return viewerState.viewerMode == .mpr
        }
        return viewerState.viewerMode == .threeD && viewerState.threeDMode == mode
    }

    private func menuItemLabel(title: String, isActive: Bool) -> some View {
        Group {
            if isActive {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }

    // MARK: - Layout Menu (RESTORED)

    private var layoutMenu: some View {
        Menu {
            ForEach(LayoutMode.allCases) { mode in
                Button {
                    withAnimation(.smooth) {
                        viewModel.setLayout(mode)
                    }
                } label: {
                    layoutIcon(for: mode)
                        .accessibilityLabel(mode.rawValue)
                }
            }
        } label: {
            layoutIcon(for: viewerState.layoutMode)
        } primaryAction: {
            withAnimation(.smooth) {
                viewModel.cycleLayout()
            }
        }
        .help("Cycle layout")
    }

    private var mprLayoutMenu: some View {
        Menu {
            ForEach(MPRLayoutMode.allCases) { mode in
                Button {
                    withAnimation(.smooth) {
                        viewerState.mprLayoutMode = mode
                    }
                } label: {
                    mprLayoutIcon(for: mode)
                        .accessibilityLabel(mode.rawValue)
                }
            }
        } label: {
            mprLayoutIcon(for: viewerState.mprLayoutMode)
        } primaryAction: {
            withAnimation(.smooth) {
                viewerState.mprLayoutMode = viewerState.mprLayoutMode.next
            }
        }
        .help("Cycle MPR layout")
        .disabled(viewerState.viewerMode != .mpr)
    }

    private func mprLayoutIcon(for mode: MPRLayoutMode) -> Image {
        switch mode {
        case .triPlanar:
            return Image(systemName: "rectangle.split.3x1")
        case .threeUp:
            return Image("3upicon")
        }
    }

    private func layoutIcon(for mode: LayoutMode) -> Image {
        switch mode {
        case .oneUp:
            return Image(systemName: "rectangle")
        case .twoUp:
            return Image(systemName: "rectangle.split.2x1")
        case .threeUp:
            return Image("3upicon")
        case .fourUp:
            return Image(systemName: "rectangle.split.2x2")
        }
    }

    // MARK: - Viewer Tools

    private var viewerToolsGroup: some View {
        HStack(spacing: 6) {
            ForEach(ViewerTool.allCases, id: \.self) { tool in
                Toggle(
                    isOn: Binding(
                        get: { viewerState.activeTool == tool },
                        set: { isOn in
                            if isOn {
                                viewModel.setActiveTool(tool)
                            } else if viewerState.activeTool == tool {
                                viewModel.setActiveTool(nil)
                            }
                        }
                    )
                ) {
                    Image(systemName: tool.symbolName)
                }
                .toggleStyle(.button)
                .tint(HeritagePACSTheme.phiHighlightYellow)
                .help(tool.rawValue)
                .disabled(viewerState.isLoadingVolume)
            }
        }
    }

    private var resetViewButton: some View {
        Button {
            viewModel.resetViewPresentation()
        } label: {
            Image(systemName: "arrow.counterclockwise")
        }
        .help("Reset View")
        .accessibilityLabel("Reset View")
        .disabled(!viewerState.hasVolume || viewerState.isLoadingVolume)
    }

    // MARK: - Primary Actions

    private var settingsButton: some View {
        Button {
            viewModel.setSettingsSheetPresented(true)
        } label: {
            Image(systemName: "gearshape")
        }
        .help("Settings")
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
    }
}
