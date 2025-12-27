import SwiftUI

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
                Rectangle()
                    .fill(viewerState.hasVolume ? HeritagePACSTheme.viewportBackground : viewportSystemBackground)
                    .overlay(
                        Rectangle()
                            .strokeBorder(.separator, lineWidth: 1)
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
                } else {
                    Placeholder3DView()
                }

                // Crosshairs
                CrosshairOverlay(size: size)
                    .allowsHitTesting(false)

                // Measurement annotation
                MeasurementOverlay(size: size)
                    .allowsHitTesting(false)

                // iOS 26: Liquid Glass overlays
                viewportOverlays(size: size)
                    .allowsHitTesting(false)

                if viewerState.isImagingViewport(index) {
                    viewportStateOverlays
                }

                if isActive {
                    Rectangle()
                        .strokeBorder(Color.accentColor, lineWidth: 1)
                        .allowsHitTesting(false)
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
        .foregroundStyle(.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .applyGlassEffect(tint: .clear)
    }

    private var cornerOverlays: some View {
        ZStack {
            // Top-left: Series info
            VStack(alignment: .leading, spacing: 2) {
                Text(viewerState.seriesTitle)
                    .font(.caption)
                    .foregroundStyle(.primary)
                Text(viewerState.seriesSubtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(6)
            .applyGlassEffect(tint: .clear)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(8)

            // Top-right: Patient info
            VStack(alignment: .trailing, spacing: 2) {
                Text(viewerState.patientDisplayName)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
                Text(viewerState.patientDetails)
                    .font(.caption2)
                    .foregroundStyle(.primary)
                Text(viewerState.acquisitionDateTimeDisplay)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(6)
            .applyGlassEffect(tint: .clear)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(8)

            // Bottom-left: Window/Level
            VStack(alignment: .leading, spacing: 2) {
                Text("W \(Int(viewerState.window))  L \(Int(viewerState.level))")
                    .font(.caption2.monospaced())
                Text("SLICE \(String(format: "%02d", viewerState.clampedSliceIndex + 1))/\(viewerState.seriesImagesDisplay)")
                    .font(.caption2.monospaced())
            }
            .foregroundStyle(.secondary)
            .padding(6)
            .applyGlassEffect(tint: .clear)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(8)

            // Bottom-right: Status
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 6, height: 6)
                Text(viewerState.hasVolume ? "ONLINE" : "NO DATA")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(6)
            .applyGlassEffect(tint: .clear)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(8)
        }
    }

    private var viewportSystemBackground: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }
}
