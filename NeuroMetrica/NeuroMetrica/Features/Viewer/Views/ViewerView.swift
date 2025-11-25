import SwiftUI
import ChromaImagingKit
import UniformTypeIdentifiers

struct ViewerView: View {
    @ObservedObject var viewModel: ViewerViewModel
    @EnvironmentObject var appSettings: AppSettings

    // For drag-based scrubbing
    @State private var accumulatedDrag: CGFloat = 0

    // For keyboard focus (macOS / iPad with hardware keyboard)
    @FocusState private var isFocused: Bool

    // For the system file importer
    @State private var isImporterPresented = false

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Background
                Rectangle()
                    .fill(Color.black)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                    )

                if let image = viewModel.currentImage {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding()
                        .gesture(sliceDragGesture)        // drag to scrub slices
                        .overlay(scrollWheelOverlay)      // scroll wheel / trackpad on macOS
                } else {
                    Text("No volume loaded")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            // Simple status readout for current slice
            Text("Slice \(viewModel.state.sliceIndex + 1) of \(max(viewModel.state.sliceCount, 1))")
                .font(.caption)
                .foregroundColor(.secondary)

            // Open button
            HStack {
                Button("Open Volume…") {
                    isImporterPresented = true
                }
                .buttonStyle(.borderedProminent)

                Spacer()
            }

            // Controls
            OrientationControlView(viewModel: viewModel)
            SliceNavigationView(viewModel: viewModel)
            WWLControlsView(viewModel: viewModel)
            backendPicker
        }
        .padding()
        // Keyboard focus and arrow-key navigation
        .focusable()
        .focused($isFocused)
        .onAppear {
            isFocused = true
        }
        .onKeyPress(.upArrow) {
            viewModel.stepSlice(by: 1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            viewModel.stepSlice(by: -1)
            return .handled
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [
                UTType(filenameExtension: "nii")!,
                UTType(filenameExtension: "gz")!
            ],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first(where: {
                    let name = $0.lastPathComponent.lowercased()
                    return name.hasSuffix(".nii") || name.hasSuffix(".nii.gz")
                }) else { return }

                Task {
                    // For sandboxed macOS/iOS apps, URLs from fileImporter are security-scoped.
                    // We must startAccessingSecurityScopedResource() before using them in C APIs.
                    let didStartAccess = url.startAccessingSecurityScopedResource()
                    defer {
                        if didStartAccess {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }

                    await viewModel.loadNIfTIVolume(from: url)
                }
            case .failure(let error):
                print("File import failed: \(error)")
            }
        }
    }

    // MARK: - Gestures

    /// Drag up/down over the image to scrub through slices.
    private var sliceDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard viewModel.state.sliceCount > 0 else { return }

                // Tune this to adjust how "sensitive" the drag is.
                let pointsPerSlice: CGFloat = 8

                let total = value.translation.height + accumulatedDrag
                let steps = Int(-total / pointsPerSlice)

                if steps != 0 {
                    viewModel.stepSlice(by: steps)
                    accumulatedDrag += CGFloat(steps) * pointsPerSlice
                }
            }
            .onEnded { _ in
                accumulatedDrag = 0
            }
    }

    // MARK: - Scroll wheel / trackpad (macOS only)

    @ViewBuilder
    private var scrollWheelOverlay: some View {
        #if os(macOS)
        ScrollWheelCatcherView { deltaY in
            guard viewModel.state.sliceCount > 0 else { return }

            // On macOS, positive deltaY is typically a scroll up (toward user)
            let step = deltaY > 0 ? 1 : -1
            viewModel.stepSlice(by: step)
        }
        .allowsHitTesting(false)
        #else
        EmptyView()
        #endif
    }

    private var backendPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Processing Backend")
                .font(.caption)
                .foregroundColor(.secondary)
            Picker("Processing Backend", selection: $appSettings.processingBackend) {
                ForEach(ProcessingBackend.allCases) { backend in
                    Text(backend.displayName).tag(backend)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

#if os(macOS)
import AppKit

/// Bridges macOS scroll wheel / trackpad events into SwiftUI.
struct ScrollWheelCatcherView: NSViewRepresentable {
    var onScroll: (CGFloat) -> Void

    final class RepresentedView: NSView {
        var onScroll: ((CGFloat) -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func scrollWheel(with event: NSEvent) {
            super.scrollWheel(with: event)
            onScroll?(event.scrollingDeltaY)
        }
    }

    func makeNSView(context: Context) -> RepresentedView {
        let view = RepresentedView()
        view.onScroll = onScroll

        // Ensure it receives scroll events
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }

        return view
    }

    func updateNSView(_ nsView: RepresentedView, context: Context) {
        nsView.onScroll = onScroll
    }
}
#endif
