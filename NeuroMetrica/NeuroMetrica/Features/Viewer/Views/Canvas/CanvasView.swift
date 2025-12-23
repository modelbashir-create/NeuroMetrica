import SwiftUI

// MARK: - Canvas View

struct CanvasView: View {
    @Environment(ViewerState.self) private var viewerState
    @ObservedObject var viewModel: ViewerViewModel
    @ObservedObject var importViewModel: ImportViewModel
    private let viewportPadding: CGFloat = 8
    private let viewportSpacing: CGFloat = 2

    var body: some View {
        ZStack {
            // Heritage black canvas (required for diagnostic imaging)
            HeritagePACSTheme.canvasBackground
                .ignoresSafeArea()

            viewportLayout
                .padding(viewportPadding)
                .background(HeritagePACSTheme.viewportBackground)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var viewportLayout: some View {
        switch viewerState.layoutMode {
        case .oneUp:
            ViewportView(index: 0, viewModel: viewModel, importViewModel: importViewModel)
                .padding(viewportSpacing)

        case .twoUp:
            HStack(spacing: viewportSpacing) {
                ViewportView(index: 0, viewModel: viewModel, importViewModel: importViewModel)
                ViewportView(index: 1, viewModel: viewModel, importViewModel: importViewModel)
            }
            .padding(viewportSpacing)

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
            .padding(viewportSpacing)

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
            .padding(viewportSpacing)
        }
    }
}
