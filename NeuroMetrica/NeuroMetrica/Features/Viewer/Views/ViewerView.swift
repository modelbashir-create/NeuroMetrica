import SwiftUI

struct ViewerView: View {
    @Environment(ViewerState.self) private var viewerState
    @ObservedObject var viewModel: ViewerViewModel
    let image: Image?
    let aspectRatio: CGFloat?
    let isLoading: Bool
    let isActive: Bool

    // For drag-based scrubbing
    @State private var accumulatedDrag: CGFloat = 0

    var body: some View {
        ZStack {
            if let image {
                image
                    .resizable()
                    .aspectRatio(aspectRatio, contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .gesture(isActive ? sliceDragGesture : nil)
                    .overlay(scrollWheelOverlay)
            } else {
                Text(isLoading ? "Loading…" : "No volume loaded")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }

    // MARK: - Gestures

    private var sliceDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard viewerState.sliceCount > 0 else { return }

                let pointsPerSlice: CGFloat = 8
                let total = value.translation.height + accumulatedDrag
                let steps = Int(-total / pointsPerSlice)

                if steps != 0 {
                guard isActive else { return }
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
        ScrollWheelCatcherView { deltaY, modifiers in
            guard viewerState.sliceCount > 0 else { return }
            guard isActive else { return }

            let isFast = modifiers.contains(.shift)
            let step = deltaY > 0 ? (isFast ? 5 : 1) : (isFast ? -5 : -1)
            viewModel.stepSlice(by: step)
        }
        .allowsHitTesting(false)
        #else
        EmptyView()
        #endif
    }
}

#if os(macOS)
import AppKit

/// Bridges macOS scroll wheel / trackpad events into SwiftUI.
struct ScrollWheelCatcherView: NSViewRepresentable {
    var onScroll: (CGFloat, NSEvent.ModifierFlags) -> Void

    final class RepresentedView: NSView {
        var onScroll: ((CGFloat, NSEvent.ModifierFlags) -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func scrollWheel(with event: NSEvent) {
            super.scrollWheel(with: event)
            onScroll?(event.scrollingDeltaY, event.modifierFlags)
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
