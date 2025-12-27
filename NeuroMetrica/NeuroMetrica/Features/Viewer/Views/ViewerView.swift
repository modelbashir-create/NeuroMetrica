import SwiftUI

struct ViewerView: View {
    @Environment(ViewerState.self) private var viewerState
    @ObservedObject var viewModel: ViewerViewModel
    let viewportIndex: Int
    let image: Image?
    let aspectRatio: CGFloat?
    let isLoading: Bool
    let isActive: Bool
    let zoom: CGFloat
    let pan: CGSize

    // For drag-based scrubbing
    @State private var accumulatedDrag: CGFloat = 0
    @State private var magnificationStartZoom: CGFloat?
    @State private var zoomDragStartZoom: CGFloat?

    var body: some View {
        ZStack {
            if let image {
                ZStack {
                    if viewerState.hasVolume {
                        HeritagePACSTheme.canvasBackground
                    }

                    image
                        .resizable()
                        .aspectRatio(aspectRatio, contentMode: .fit)
                        .scaleEffect(zoom)
                        .offset(pan)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                }
                .overlay(scrollWheelOverlay)
            } else {
                Text(isLoading ? "Loading…" : "No volume loaded")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .contentShape(Rectangle())
        .gesture(isActive ? activeDragGesture : nil)
        .simultaneousGesture(isActive ? zoomGesture : nil)
    }

    // MARK: - Gestures

    private var activeDragGesture: AnyGesture<DragGesture.Value> {
        viewerState.activeTool == .zoom ? zoomDragGesture : sliceDragGesture
    }

    private var sliceDragGesture: AnyGesture<DragGesture.Value> {
        AnyGesture(
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
        )
    }

    private var zoomDragGesture: AnyGesture<DragGesture.Value> {
        AnyGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard isActive else { return }
                    guard viewerState.activeTool == .zoom else { return }
                    if zoomDragStartZoom == nil {
                        zoomDragStartZoom = viewerState.zoom(for: viewportIndex)
                    }
                    guard let startZoom = zoomDragStartZoom else { return }
                    let factor = pow(1.01, -value.translation.height)
                    viewModel.setZoom(for: viewportIndex, to: startZoom * factor)
                }
                .onEnded { _ in
                    zoomDragStartZoom = nil
                }
        )
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                guard isActive else { return }
                if magnificationStartZoom == nil {
                    magnificationStartZoom = viewerState.zoom(for: viewportIndex)
                }
                guard let startZoom = magnificationStartZoom else { return }
                viewModel.setZoom(for: viewportIndex, to: startZoom * value)
            }
            .onEnded { _ in
                magnificationStartZoom = nil
            }
    }

    // MARK: - Scroll wheel / trackpad (macOS only)

    @ViewBuilder
    private var scrollWheelOverlay: some View {
        #if os(macOS)
        ScrollWheelCatcherView(
            onScroll: { deltaY, modifiers, isPrecise, phase, momentumPhase in
                guard isActive else { return }

                if modifiers.contains(.command) {
                    let factor: CGFloat = deltaY > 0 ? 0.9 : 1.1
                    viewModel.stepZoom(for: viewportIndex, by: factor)
                    return
                }

                guard viewerState.sliceCount > 0 else { return }
                viewModel.handleScrollEvent(
                    deltaY: deltaY,
                    viewportIndex: viewportIndex,
                    isPrecise: isPrecise,
                    isFast: modifiers.contains(.shift),
                    phase: phase,
                    momentumPhase: momentumPhase
                )
            },
            onMagnify: { magnification in
                guard isActive else { return }
                let factor = max(0.1, 1 + magnification)
                viewModel.stepZoom(for: viewportIndex, by: factor)
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #else
        EmptyView()
        #endif
    }
}

#if os(macOS)
import AppKit

/// Bridges macOS scroll wheel / trackpad events into SwiftUI.
struct ScrollWheelCatcherView: NSViewRepresentable {
    var onScroll: (CGFloat, NSEvent.ModifierFlags, Bool, NSEvent.Phase, NSEvent.Phase) -> Void
    var onMagnify: (CGFloat) -> Void

    final class RepresentedView: NSView {
        var onScroll: ((CGFloat, NSEvent.ModifierFlags, Bool, NSEvent.Phase, NSEvent.Phase) -> Void)?
        var onMagnify: ((CGFloat) -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func scrollWheel(with event: NSEvent) {
            super.scrollWheel(with: event)
            onScroll?(
                event.scrollingDeltaY,
                event.modifierFlags,
                event.hasPreciseScrollingDeltas,
                event.phase,
                event.momentumPhase
            )
        }

        override func magnify(with event: NSEvent) {
            super.magnify(with: event)
            onMagnify?(event.magnification)
        }
    }

    func makeNSView(context: Context) -> RepresentedView {
        let view = RepresentedView()
        view.onScroll = onScroll
        view.onMagnify = onMagnify

        // Ensure it receives scroll events
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }

        return view
    }

    func updateNSView(_ nsView: RepresentedView, context: Context) {
        nsView.onScroll = onScroll
        nsView.onMagnify = onMagnify
    }
}
#endif
