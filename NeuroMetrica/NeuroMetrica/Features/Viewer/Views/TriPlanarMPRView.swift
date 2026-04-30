import SwiftUI
#if os(macOS)
import AppKit
#endif

struct TriPlanarMPRView: View {
    @Environment(ViewerState.self) private var viewerState
    @ObservedObject var viewModel: ViewerViewModel

    var body: some View {
        Group {
            #if os(iOS)
            if horizontalSizeClass == .compact {
                compactLayout
            } else {
                regularLayout
            }
            #else
            regularLayout
            #endif
        }
        .onAppear {
            viewModel.refreshMPRSlices()
        }
    }

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    private var panes: [MPRPane] {
        [.axial, .coronal, .sagittal]
    }

    private var regularLayout: some View {
        Group {
            switch viewerState.mprLayoutMode {
            case .triPlanar:
                threeAcrossLayout
            case .threeUp:
                threeUpLayout
            }
        }
    }

    private var compactLayout: some View {
        Group {
            switch viewerState.mprLayoutMode {
            case .triPlanar:
                compactThreeAcrossLayout
            case .threeUp:
                threeUpLayout
            }
        }
    }

    private var threeAcrossLayout: some View {
        HStack(spacing: 0) {
            ForEach(panes) { pane in
                MPRPaneView(pane: pane, viewModel: viewModel)
            }
        }
    }

    private var compactThreeAcrossLayout: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                ForEach(panes) { pane in
                    MPRPaneView(pane: pane, viewModel: viewModel)
                        .frame(height: proxy.size.height / CGFloat(panes.count))
                }
            }
        }
    }

    private var threeUpLayout: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                MPRPaneView(pane: .axial, viewModel: viewModel)
                    .frame(height: proxy.size.height * 0.6)

                HStack(spacing: 0) {
                    MPRPaneView(pane: .coronal, viewModel: viewModel)
                    MPRPaneView(pane: .sagittal, viewModel: viewModel)
                }
            }
        }
    }
}

private struct MPRPaneView: View {
    @Environment(ViewerState.self) private var viewerState
    let pane: MPRPane
    @ObservedObject var viewModel: ViewerViewModel

    private let overlayMargin: CGFloat = 16

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let contentRect = CGRect(origin: .zero, size: size).insetBy(dx: overlayMargin, dy: overlayMargin)
            let aspectRatio = viewModel.mprAspectRatio(for: pane)

            ZStack {
                Rectangle()
                    .fill(HeritagePACSTheme.viewportBackground)
                    .overlay(Rectangle().strokeBorder(HeritagePACSTheme.viewportBorder, lineWidth: 1))

                if let image = viewModel.mprImage(for: pane) {
                    image
                        .resizable()
                        .aspectRatio(aspectRatio, contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .overlay(scrollWheelOverlay)
                } else {
                    Text(viewerState.isLoadingVolume ? "Loading…" : "No volume loaded")
                        .foregroundStyle(HeritagePACSTheme.overlayTextSecondary)
                        .padding()
                }

                if let crosshairPoint = viewModel.mprCrosshairViewPoint(
                    for: pane,
                    viewSize: size,
                    contentRect: contentRect,
                    aspectRatio: aspectRatio
                ) {
                    let axes = MPRCrosshairStyle.axes(for: pane)
                    CrosshairOverlay(
                        contentRect: contentRect,
                        position: crosshairPoint,
                        horizontalColor: axes.axisU.color,
                        verticalColor: axes.axisV.color
                    )
                }

                cornerOverlays
                    .allowsHitTesting(false)

                stateOverlays
            }
            .contentShape(Rectangle())
            .gesture(crosshairDragGesture(viewSize: size, contentRect: contentRect, aspectRatio: aspectRatio))
        }
    }

    private func crosshairDragGesture(
        viewSize: CGSize,
        contentRect: CGRect,
        aspectRatio: CGFloat?
    ) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                viewModel.setMPRCrosshairFromViewPoint(
                    value.location,
                    pane: pane,
                    viewSize: viewSize,
                    contentRect: contentRect,
                    aspectRatio: aspectRatio
                )
            }
    }

    @ViewBuilder
    private var scrollWheelOverlay: some View {
        #if os(macOS)
        ScrollWheelCatcherView(
            onScroll: { deltaY, modifiers, isPrecise, _, _ in
                viewModel.handleMPRScroll(
                    deltaY: deltaY,
                    pane: pane,
                    isPrecise: isPrecise,
                    isFast: modifiers.contains(.shift)
                )
            },
            onMagnify: { _ in },
            onRightMouseDown: { _, _ in },
            onRightMouseDragged: { _ in },
            onRightMouseUp: {}
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #else
        EmptyView()
        #endif
    }

    private var cornerOverlays: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewerState.seriesTitle)
                    .font(.caption)
                    .foregroundStyle(HeritagePACSTheme.overlayTextPrimary)
                Text(viewerState.seriesSubtitle)
                    .font(.caption2)
                    .foregroundStyle(HeritagePACSTheme.overlayTextSecondary)
            }
            .padding(6)
            .applyGlassEffect(tint: .clear)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(viewerState.patientDisplayName)
                    .font(.caption.bold())
                    .foregroundStyle(HeritagePACSTheme.overlayTextPrimary)
                Text(viewerState.patientDetails)
                    .font(.caption2)
                    .foregroundStyle(HeritagePACSTheme.overlayTextPrimary)
                Text(viewerState.acquisitionDateTimeDisplay)
                    .font(.caption2)
                    .foregroundStyle(HeritagePACSTheme.overlayTextSecondary)
            }
            .padding(6)
            .applyGlassEffect(tint: .clear)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(8)

            VStack(alignment: .leading, spacing: 2) {
                Text("W \(Int(viewerState.window))  L \(Int(viewerState.level))")
                    .font(.caption2.monospaced())
                Text(viewModel.mprOverlaySliceDisplay(for: pane))
                    .font(.caption2.monospaced())
            }
            .foregroundStyle(HeritagePACSTheme.overlayTextSecondary)
            .padding(6)
            .applyGlassEffect(tint: .clear)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(8)

            HStack(spacing: 6) {
                Circle()
                    .fill(HeritagePACSTheme.statusOK)
                    .frame(width: 6, height: 6)
                Text(viewerState.hasVolume ? "ONLINE" : "NO DATA")
                    .font(.caption2)
                    .foregroundStyle(HeritagePACSTheme.overlayTextSecondary)
            }
            .padding(6)
            .applyGlassEffect(tint: .clear)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(8)
        }
    }

    @ViewBuilder
    private var stateOverlays: some View {
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
                onChooseAnother: {}
            )
        }
    }
}
