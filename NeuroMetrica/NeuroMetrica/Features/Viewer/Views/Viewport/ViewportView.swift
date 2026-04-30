import SwiftUI

// MARK: - Individual Viewport (iOS 26 Liquid Glass)

struct ViewportView: View {
    @Environment(ViewerState.self) private var viewerState
    let index: Int
    @ObservedObject var viewModel: ViewerViewModel
    @ObservedObject var importViewModel: ImportViewModel

    private let overlayMargin: CGFloat = 16
    @State private var isCrosshairDragging = false

    private var isActive: Bool {
        index == viewerState.clampedActiveIndex
    }

    private var sliceDisplayText: String? {
        guard let sliceInfo = viewModel.sliceInfo(for: index) else { return nil }
        let currentSlice = min(max(sliceInfo.displayIndex + 1, 1), max(sliceInfo.sliceCount, 1))
        return "SLICE \(String(format: "%02d", currentSlice))/\(sliceInfo.sliceCount)"
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let contentRect = CGRect(origin: .zero, size: size).insetBy(dx: overlayMargin, dy: overlayMargin)
            let zoom = viewerState.zoom(for: index)
            let pan = viewerState.pan(for: index)
            let aspectRatio = viewModel.displayAspectRatio(for: index)

            ZStack {
                // Base viewport
                Rectangle()
                    .fill(HeritagePACSTheme.viewportBackground)
                    .overlay(
                        Rectangle()
                            .strokeBorder(HeritagePACSTheme.viewportBorder, lineWidth: 1)
                    )

                if viewerState.isImagingViewport(index) {
                    ViewerView(
                        viewModel: viewModel,
                        viewportIndex: index,
                        image: viewModel.image(for: index),
                        aspectRatio: viewModel.displayAspectRatio(for: index),
                        isLoading: viewerState.isLoadingVolume,
                        isActive: index == viewerState.clampedActiveIndex,
                        zoom: viewerState.zoom(for: index),
                        pan: viewerState.pan(for: index)
                    )
                    if let labels = viewModel.orientationLabels(for: index) {
                        OrientationLabelsOverlay(labels: labels)
                    }
                } else {
                    Placeholder3DView()
                }

                // Crosshairs
                if let crosshairPoint = viewModel.crosshairViewPoint(
                    for: index,
                    viewSize: size,
                    contentRect: contentRect,
                    aspectRatio: aspectRatio,
                    zoom: zoom,
                    pan: pan
                ) {
                        CrosshairOverlay(
                            contentRect: contentRect,
                            position: crosshairPoint,
                            horizontalColor: HeritagePACSTheme.crosshairColor,
                            verticalColor: HeritagePACSTheme.crosshairColor
                        )
                        .gesture(crosshairDragGesture(
                            viewSize: size,
                            contentRect: contentRect,
                            aspectRatio: aspectRatio,
                            zoom: zoom,
                            pan: pan
                        ))
                }

                // iOS 26: Liquid Glass overlays
                viewportOverlays(size: size)
                    .allowsHitTesting(false)

                if viewerState.isImagingViewport(index) {
                    viewportStateOverlays
                }

                if isActive {
                    Rectangle()
                        .strokeBorder(HeritagePACSTheme.activeViewportBorder, lineWidth: 1)
                        .allowsHitTesting(false)
                }
            }
            .onAppear {
                viewModel.updateViewportGeometry(for: index, viewSize: size, contentRect: contentRect)
            }
            .onChange(of: size) { _, newSize in
                let newRect = CGRect(origin: .zero, size: newSize)
                    .insetBy(dx: overlayMargin, dy: overlayMargin)
                viewModel.updateViewportGeometry(for: index, viewSize: newSize, contentRect: newRect)
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

    private func crosshairDragGesture(
        viewSize: CGSize,
        contentRect: CGRect,
        aspectRatio: CGFloat?,
        zoom: CGFloat,
        pan: CGSize
    ) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard isActive else { return }
                if !isCrosshairDragging {
                    isCrosshairDragging = viewModel.beginCrosshairDrag(
                        at: value.startLocation,
                        viewportIndex: index,
                        viewSize: viewSize,
                        contentRect: contentRect,
                        aspectRatio: aspectRatio,
                        zoom: zoom,
                        pan: pan
                    )
                }
                guard isCrosshairDragging else { return }
                viewModel.updateCrosshairDrag(
                    to: value.location,
                    viewportIndex: index,
                    viewSize: viewSize,
                    contentRect: contentRect,
                    aspectRatio: aspectRatio,
                    zoom: zoom,
                    pan: pan
                )
            }
            .onEnded { _ in
                guard isCrosshairDragging else { return }
                viewModel.endCrosshairDrag(for: index)
                isCrosshairDragging = false
            }
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
        // Corner overlays
        cornerOverlays
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
            .applyGlassEffect(tint: .clear)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(8)

            // Top-right: Patient info
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

            // Bottom-left: Window/Level
            VStack(alignment: .leading, spacing: 2) {
                Text("W \(Int(viewerState.window))  L \(Int(viewerState.level))")
                    .font(.caption2.monospaced())
                if let sliceDisplayText {
                    Text(sliceDisplayText)
                        .font(.caption2.monospaced())
                }
            }
            .foregroundStyle(HeritagePACSTheme.overlayTextSecondary)
            .padding(6)
            .applyGlassEffect(tint: .clear)
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
            .applyGlassEffect(tint: .clear)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(8)
        }
    }

}
