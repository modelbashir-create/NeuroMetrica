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
            layoutMenu
        }

        ToolbarItemGroup(placement: .principal) {

            viewerToolsGroup
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
                    menuItemLabel(
                        title: mode.rawValue,
                        isActive: viewerState.viewerMode == .threeD
                            && viewerState.threeDMode == mode
                    )
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
        viewerState.viewerMode == .twoD ? "2D" : viewerState.threeDMode.rawValue
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
                    Label {
                        Text(mode.rawValue)
                    } icon: {
                        Image(systemName: layoutIcon(for: mode))
                    }
                }
            }
        } label: {
            Image(systemName: layoutIcon(for: viewerState.layoutMode))
        } primaryAction: {
            withAnimation(.smooth) {
                viewModel.cycleLayout()
            }
        }
        .help("Cycle layout")
    }

    private func layoutIcon(for mode: LayoutMode) -> String {
        switch mode {
        case .oneUp:   return "rectangle"
        case .twoUp:   return "rectangle.split.2x1"
        case .threeUp: return "rectangle.split.1x2"
        case .fourUp:  return "rectangle.split.2x2"
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
