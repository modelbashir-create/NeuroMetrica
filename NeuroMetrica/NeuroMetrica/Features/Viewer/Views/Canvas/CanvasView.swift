import SwiftUI

// MARK: - Canvas View

struct CanvasView: View {
    @Environment(ViewerState.self) private var viewerState
    @ObservedObject var viewModel: ViewerViewModel
    @ObservedObject var importViewModel: ImportViewModel
    private let viewportPadding: CGFloat = 0
    private let viewportSpacing: CGFloat = 0
    @State private var isCanvasDropTargeted: Bool = false

    var body: some View {
        ZStack {
            (viewerState.hasVolume ? HeritagePACSTheme.canvasBackground : canvasSystemBackground)

            if viewerState.hasVolume {
                if viewerState.viewerMode == .mpr {
                    TriPlanarMPRView(viewModel: viewModel)
                        .padding(viewportPadding)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    viewportLayout
                        .padding(viewportPadding)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                emptyStateDropZone
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var viewportLayout: some View {
        switch viewerState.layoutMode {
        case .oneUp:
            ViewportView(index: 0, viewModel: viewModel, importViewModel: importViewModel)

        case .twoUp:
            HStack(spacing: viewportSpacing) {
                ViewportView(index: 0, viewModel: viewModel, importViewModel: importViewModel)
                ViewportView(index: 1, viewModel: viewModel, importViewModel: importViewModel)
            }

        case .threeUp:
            GeometryReader { proxy in
                VStack(spacing: viewportSpacing) {
                    ViewportView(index: 0, viewModel: viewModel, importViewModel: importViewModel)
                        .frame(height: proxy.size.height * 0.6)

                    HStack(spacing: viewportSpacing) {
                        ViewportView(index: 1, viewModel: viewModel, importViewModel: importViewModel)
                        ViewportView(index: 2, viewModel: viewModel, importViewModel: importViewModel)
                    }
                }
            }

        case .fourUp:
            VStack(spacing: viewportSpacing) {
                HStack(spacing: viewportSpacing) {
                    ViewportView(index: 0, viewModel: viewModel, importViewModel: importViewModel)
                    ViewportView(index: 1, viewModel: viewModel, importViewModel: importViewModel)
                }
                HStack(spacing: viewportSpacing) {
                    ViewportView(index: 2, viewModel: viewModel, importViewModel: importViewModel)
                    ViewportView(index: 3, viewModel: viewModel, importViewModel: importViewModel)
                }
            }
        }
    }

    // Canvas empty-state drop target UI; drop handling routes through the existing import/open flow.
    private var emptyStateDropZone: some View {
        ZStack {
            dropZoneCard
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onDrop(of: importViewModel.allowedContentTypes, isTargeted: $isCanvasDropTargeted) { providers in
            handleCanvasDrop(providers: providers)
        }
    }

    private var canvasSystemBackground: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }

    // Canvas empty-state drop handler: routes dropped URLs through ImportViewModel's existing import/open flow.
    private func handleCanvasDrop(providers: [NSItemProvider]) -> Bool {
        importViewModel.handleDroppedProviders(providers)
    }

    private var dropZoneCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.primary)

            Text("Drop studies, series, or volumes to open")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("Supports DICOM and other imaging formats.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(maxWidth: 420)
    }
}
