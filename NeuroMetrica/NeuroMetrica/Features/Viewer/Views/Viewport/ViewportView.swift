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
                    .fill(HeritagePACSTheme.viewportBackground)
                    .overlay(
                        Rectangle()
                            .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                    )
                    .overlay(
                        Rectangle()
                            .strokeBorder(
                                HeritagePACSTheme.activeViewportBorder.opacity(isActive ? 0.75 : 0),
                                lineWidth: isActive ? 2 : 0
                            )
                    )

                if viewerState.isImagingViewport(index) {
                    ViewerView(
                        viewModel: viewModel,
                        image: viewModel.image(for: index),
                        aspectRatio: viewModel.displayAspectRatio(for: index),
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
