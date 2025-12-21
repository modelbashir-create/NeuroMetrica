import SwiftUI
import Observation

// MARK: - Shared Enums

enum LayoutMode: String, CaseIterable, Identifiable {
    case oneUp   = "1-up"
    case twoUp   = "2-up"
    case threeUp = "3-up"
    case fourUp  = "4-up"

    var id: String { rawValue }
    
    var next: LayoutMode {
        switch self {
        case .oneUp:   return .twoUp
        case .twoUp:   return .threeUp
        case .threeUp: return .fourUp
        case .fourUp:  return .oneUp
        }
    }
    
    var maxViewportIndex: Int {
        switch self {
        case .oneUp:   return 0
        case .twoUp:   return 1
        case .threeUp: return 2
        case .fourUp:  return 3
        }
    }
}

enum ViewerMode: String, CaseIterable, Identifiable {
    case twoD   = "2D"
    case threeD = "3D"

    var id: String { rawValue }
}

enum ThreeDSubMode: String, CaseIterable, Identifiable {
    case mpr = "MPR"
    case vr  = "VR"
    case mip = "MIP"

    var id: String { rawValue }
}

enum ViewerTool: String, CaseIterable, Identifiable {
    case windowLevel = "Window/Level"
    case pan = "Pan"
    case zoom = "Zoom"
    case measure = "Measure"
    case cine = "Cine"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .windowLevel: return "slider.horizontal.3"
        case .pan: return "hand.draw"
        case .zoom: return "plus.magnifyingglass"
        case .measure: return "ruler"
        case .cine: return "play.fill"
        }
    }
}


// MARK: - Observable Viewer State

@Observable
@MainActor
final class ViewerState {
    var layoutMode: LayoutMode = .oneUp
    var viewerMode: ViewerMode = .twoD
    var threeDMode: ThreeDSubMode = .mpr
    var activeViewportIndex: Int = 0
    var activeTool: ViewerTool = .windowLevel
    
    // Sheet presentation states
    var showExportSheet = false
    var showSettingsSheet = false
    
    var clampedActiveIndex: Int {
        min(max(activeViewportIndex, 0), layoutMode.maxViewportIndex)
    }
    
    func cycleLayout() {
        layoutMode = layoutMode.next
        if activeViewportIndex > layoutMode.maxViewportIndex {
            activeViewportIndex = 0
        }
    }
    
    func toggleViewerMode() {
        viewerMode = (viewerMode == .twoD) ? .threeD : .twoD
    }
    
    func setLayout(_ mode: LayoutMode) {
        layoutMode = mode
        if activeViewportIndex > layoutMode.maxViewportIndex {
            activeViewportIndex = 0
        }
    }
}


// MARK: - Heritage PACS Theme (Diagnostic Black Preserved)

struct HeritagePACSTheme {
    // Core surfaces - heritage black for medical imaging (clinically required)
    static let canvasBackground   = Color.black
    static let viewportBackground = Color(red: 0.02, green: 0.02, blue: 0.04)
    
    // Active viewport accent
    static let activeViewportBorder = Color(red: 0.30, green: 0.80, blue: 0.40)
    
    // Overlay text
    static let overlayTextPrimary   = Color.white
    static let overlayTextSecondary = Color(white: 0.7)
    
    // PHI highlight
    static let phiHighlightYellow = Color(red: 1.0, green: 0.86, blue: 0.45)
    
    // Annotations
    static let crosshairColor   = Color(red: 0.65, green: 0.90, blue: 1.0)
    static let measurementColor = Color(red: 0.10, green: 0.78, blue: 0.88)
    
    // Status indicators
    static let statusOK      = Color(red: 0.30, green: 0.80, blue: 0.40)
    static let statusWarning = Color(red: 1.00, green: 0.75, blue: 0.30)
    static let statusError   = Color(red: 1.00, green: 0.35, blue: 0.35)
}


// MARK: - Root ContentView

struct ContentView: View {
    @State private var viewerState = ViewerState()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @Binding var inspectorPresented: Bool
    
    // iOS 26: Namespaces for morphing sheet transitions
    @Namespace private var exportTransition
    @Namespace private var settingsTransition

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
        } detail: {
            CanvasView()
                .navigationTitle("")
                #if os(iOS)
                .toolbar(.hidden, for: .navigationBar)
                #endif
        }
        .environment(viewerState)
        .inspector(isPresented: $inspectorPresented) {
            InspectorView()
                .environment(viewerState)
                .inspectorColumnWidth(min: 280, ideal: 320, max: 400)
        }
        .toolbar { toolbarContent }
        .toolbarRole(.editor)
        // iOS 26: Morphing sheet presentations
        .sheet(isPresented: $viewerState.showExportSheet) {
            ExportSheetView()
                .presentationDetents([.medium, .large])
                .applyMorphingTransition(id: "export", in: exportTransition)
        }
        .sheet(isPresented: $viewerState.showSettingsSheet) {
            SettingsSheetView()
                .environment(viewerState)
                .presentationDetents([.medium, .large])
                .applyMorphingTransition(id: "settings", in: settingsTransition)
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
    
    private var viewModeMenu: some View {
        Menu {
            Button {
                viewerState.viewerMode = .twoD
            } label: {
                Label("2D", systemImage: viewerState.viewerMode == .twoD ? "checkmark" : "square")
            }
            
            Divider()
            
            ForEach(ThreeDSubMode.allCases) { mode in
                Button {
                    viewerState.viewerMode = .threeD
                    viewerState.threeDMode = mode
                } label: {
                    Label(mode.rawValue, systemImage: viewerState.viewerMode == .threeD && viewerState.threeDMode == mode ? "checkmark" : "square")
                }
            }
        } label: {
            Image(systemName: viewerState.viewerMode == .twoD ? "cube" : "cube.fill")
        } primaryAction: {
            viewerState.toggleViewerMode()
        }
        .help("Toggle 2D/3D")
    }
    
    private var layoutMenu: some View {
        Menu {
            ForEach(LayoutMode.allCases) { mode in
                Button {
                    withAnimation(.smooth) {
                        viewerState.setLayout(mode)
                    }
                } label: {
                    Label(mode.rawValue, systemImage: layoutIcon(for: mode))
                }
            }
        } label: {
            layoutIconView
        } primaryAction: {
            withAnimation(.smooth) {
                viewerState.cycleLayout()
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
    
    private var viewerToolsGroup: some View {
        ControlGroup {
            ForEach(ViewerTool.allCases) { tool in
                Button {
                    viewerState.activeTool = tool
                } label: {
                    Image(systemName: tool.icon)
                }
                .help(tool.rawValue)
            }
        }
        .controlGroupStyle(.navigation)
    }
    
    private var settingsButton: some View {
        Button {
            viewerState.showSettingsSheet = true
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
            viewerState.showExportSheet = true
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


// MARK: - Sidebar Data Model

struct Study: Identifiable, Hashable {
    let id: String
    let title: String
    let modality: String
    let date: Date
    let patient: String
    let seriesCount: Int
    
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


// MARK: - Sidebar View

struct SidebarView: View {
    @SceneStorage("selectedStudyID") private var selectedStudyID: String?
    
    private let studies: [Study] = [
        Study(id: "1", title: "MR Brain w/o Contrast", modality: "MR", date: .now, patient: "DOE, JOHN", seriesCount: 12),
        Study(id: "2", title: "CT Head w/ Contrast", modality: "CT", date: .now.addingTimeInterval(-86400), patient: "DOE, JOHN", seriesCount: 3),
        Study(id: "3", title: "MR Spine Cervical", modality: "MR", date: .now.addingTimeInterval(-86400 * 3), patient: "DOE, JOHN", seriesCount: 8),
        Study(id: "4", title: "CT Chest", modality: "CT", date: .now.addingTimeInterval(-86400 * 10), patient: "DOE, JOHN", seriesCount: 2),
    ]
    
    private var todayStudies: [Study] { studies.filter { $0.isToday } }
    private var thisWeekStudies: [Study] { studies.filter { !$0.isToday && $0.isThisWeek } }
    private var olderStudies: [Study] { studies.filter { !$0.isThisWeek } }
    
    var body: some View {
        List(selection: $selectedStudyID) {
            if !todayStudies.isEmpty {
                Section("Today") {
                    ForEach(todayStudies) { study in
                        StudyRow(study: study)
                            .tag(study.id)
                    }
                }
            }
            
            if !thisWeekStudies.isEmpty {
                Section("This Week") {
                    ForEach(thisWeekStudies) { study in
                        StudyRow(study: study)
                            .tag(study.id)
                    }
                }
            }
            
            if !olderStudies.isEmpty {
                Section("Earlier") {
                    ForEach(olderStudies) { study in
                        StudyRow(study: study)
                            .tag(study.id)
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
}

struct StudyRow: View {
    let study: Study
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(study.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Spacer()
                
                Text(study.modality)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
            
            HStack {
                Text(study.patient)
                Text("•")
                Text(study.dateFormatted)
                Text("•")
                Text("\(study.seriesCount) series")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .padding(.vertical, 2)
    }
}


// MARK: - Canvas View

struct CanvasView: View {
    @Environment(ViewerState.self) private var viewerState

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
            ViewportView(index: 0)
                .padding(4)

        case .twoUp:
            HStack(spacing: 2) {
                ViewportView(index: 0)
                ViewportView(index: 1)
            }
            .padding(4)

        case .threeUp:
            GeometryReader { proxy in
                VStack(spacing: 2) {
                    ViewportView(index: 0)
                        .frame(height: proxy.size.height * 0.6)
                    
                    HStack(spacing: 2) {
                        ViewportView(index: 1)
                        ViewportView(index: 2)
                    }
                }
            }
            .padding(4)

        case .fourUp:
            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    ViewportView(index: 0)
                    ViewportView(index: 1)
                }
                HStack(spacing: 2) {
                    ViewportView(index: 2)
                    ViewportView(index: 3)
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
                
                // Crosshairs
                CrosshairOverlay(size: size)
                
                // Measurement annotation
                MeasurementOverlay(size: size)
                
                // iOS 26: Liquid Glass overlays
                viewportOverlays(size: size)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            viewerState.activeViewportIndex = index
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Viewport \(index + 1)")
        .accessibilityAddTraits(isActive ? .isSelected : [])
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
                Text("AX T2 FLAIR")
                    .font(.caption)
                    .foregroundStyle(HeritagePACSTheme.overlayTextPrimary)
                Text("SER 3  IMG \(index + 1)")
                    .font(.caption2)
                    .foregroundStyle(HeritagePACSTheme.overlayTextSecondary)
            }
            .padding(6)
            .applyGlassEffect(tint: .black.opacity(0.3))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(8)
            
            // Top-right: Patient info
            VStack(alignment: .trailing, spacing: 2) {
                Text("DOE^JOHN")
                    .font(.caption.bold())
                    .foregroundStyle(HeritagePACSTheme.phiHighlightYellow)
                Text("ID 12345678 • M/45")
                    .font(.caption2)
                    .foregroundStyle(HeritagePACSTheme.overlayTextPrimary)
                Text("2025-05-23 14:32")
                    .font(.caption2)
                    .foregroundStyle(HeritagePACSTheme.overlayTextSecondary)
            }
            .padding(6)
            .applyGlassEffect(tint: .black.opacity(0.3))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(8)
            
            // Bottom-left: Window/Level
            VStack(alignment: .leading, spacing: 2) {
                Text("W 350  L 40")
                    .font(.caption2.monospaced())
                Text("SLICE \(String(format: "%02d", index + 1))/48")
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
                Text("ONLINE")
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


// MARK: - Inspector View (iOS 26 Design)

struct InspectorView: View {
    @Environment(ViewerState.self) private var viewerState
    @State private var selectedTab: InspectorTab = .display
    
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
                        DisplayTabContent()
                    case .measurements:
                        MeasurementsTabContent()
                    case .analysis:
                        AnalysisTabContent()
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        // iOS 26: Let system apply glass to inspector background
        #if os(iOS)
        .navigationTitle("Inspector")
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct DisplayTabContent: View {
    @Environment(ViewerState.self) private var viewerState
    @State private var linkViewports = true
    @State private var lockZoom = false
    @State private var showCrosshair = true
    @State private var showPatientInfo = true
    @State private var windowValue: Double = 350
    @State private var levelValue: Double = 40
    
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
            
            // Window/Level section
            GroupBox("Window / Level") {
                VStack(alignment: .leading, spacing: 12) {
                    LabeledContent("Preset") {
                        Menu("Brain") {
                            Button("Brain (W 80 / L 40)") { windowValue = 80; levelValue = 40 }
                            Button("Subdural (W 200 / L 80)") { windowValue = 200; levelValue = 80 }
                            Button("Stroke (W 40 / L 40)") { windowValue = 40; levelValue = 40 }
                            Button("Bone (W 2500 / L 500)") { windowValue = 2500; levelValue = 500 }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Window")
                            Spacer()
                            Text("\(Int(windowValue))")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $windowValue, in: 1...4096)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Level")
                            Spacer()
                            Text("\(Int(levelValue))")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $levelValue, in: -1024...3072)
                    }
                }
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
    @State private var enableShading = true
    @State private var showClippingPlanes = false
    @State private var aiModel = "segmentation"
    @State private var aiOverlay = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 3D Mode section
            GroupBox("3D Rendering") {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Mode", selection: Bindable(viewerState).threeDMode) {
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


// MARK: - Settings Sheet (iOS 26 Liquid Glass)

struct SettingsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ViewerState.self) private var viewerState
    @State private var defaultLayout: LayoutMode = .oneUp
    @State private var autoPlayCine = false
    @State private var cineFrameRate: Double = 15
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Defaults") {
                    Picker("Default Layout", selection: $defaultLayout) {
                        ForEach(LayoutMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                }
                
                Section("Cine") {
                    Toggle("Auto-play on Load", isOn: $autoPlayCine)
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Frame Rate")
                            Spacer()
                            Text("\(Int(cineFrameRate)) fps")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $cineFrameRate, in: 1...60, step: 1)
                    }
                }
                
                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Build", value: "2025.11")
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

