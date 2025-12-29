import SwiftUI
#if os(macOS)
import AppKit
#endif

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
        if viewerState.activeTool == .zoom {
            return zoomDragGesture
        }
        if viewerState.activeTool == .pan {
            return panDragGesture
        }
        if viewerState.activeTool == nil || viewerState.activeTool == .windowLevel {
            return windowLevelDragGesture
        }
        return noOpDragGesture
    }

    private var windowLevelDragGesture: AnyGesture<DragGesture.Value> {
        AnyGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard isActive else { return }
                    viewModel.beginWindowLevelDrag(
                        at: value.startLocation,
                        viewportIndex: viewportIndex
                    )
                    viewModel.updateWindowLevelDrag(
                        to: value.location,
                        viewportIndex: viewportIndex,
                        isFineAdjustment: isFineAdjustmentActive,
                        forceAxisLock: isAxisLockForced
                    )
                }
                .onEnded { _ in
                    viewModel.endWindowLevelDrag(for: viewportIndex)
                }
        )
    }

    private var panDragGesture: AnyGesture<DragGesture.Value> {
        AnyGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard isActive else { return }
                    viewModel.beginPanDrag(for: viewportIndex)
                    viewModel.updatePanDrag(for: viewportIndex, translation: value.translation)
                }
                .onEnded { _ in
                    viewModel.endPanDrag(for: viewportIndex)
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

    private var noOpDragGesture: AnyGesture<DragGesture.Value> {
        AnyGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in }
                .onEnded { _ in }
        )
    }

    private var isFineAdjustmentActive: Bool {
        #if os(macOS)
        return NSEvent.modifierFlags.contains(.option)
        #else
        return false
        #endif
    }

    private var isAxisLockForced: Bool {
        #if os(macOS)
        return NSEvent.modifierFlags.contains(.shift)
        #else
        return false
        #endif
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
            },
            onRightMouseDown: { _, clickCount in
                guard isActive else { return }
                if clickCount == 2 {
                    viewModel.zoomFitActiveView()
                    return
                }
                guard viewerState.activeTool == .pan else { return }
                viewModel.beginPanDrag(for: viewportIndex)
            },
            onRightMouseDragged: { translation in
                guard isActive else { return }
                guard viewerState.activeTool == .pan else { return }
                viewModel.updatePanDrag(for: viewportIndex, translation: translation)
            },
            onRightMouseUp: {
                guard isActive else { return }
                guard viewerState.activeTool == .pan else { return }
                viewModel.endPanDrag(for: viewportIndex)
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
    var onRightMouseDown: (CGPoint, Int) -> Void
    var onRightMouseDragged: (CGSize) -> Void
    var onRightMouseUp: () -> Void

    final class RepresentedView: NSView {
        var onScroll: ((CGFloat, NSEvent.ModifierFlags, Bool, NSEvent.Phase, NSEvent.Phase) -> Void)?
        var onMagnify: ((CGFloat) -> Void)?
        var onRightMouseDown: ((CGPoint, Int) -> Void)?
        var onRightMouseDragged: ((CGSize) -> Void)?
        var onRightMouseUp: (() -> Void)?
        private var rightMouseDownLocation: NSPoint?

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

        override func rightMouseDown(with event: NSEvent) {
            super.rightMouseDown(with: event)
            let location = convert(event.locationInWindow, from: nil)
            if event.clickCount == 2 {
                rightMouseDownLocation = nil
                onRightMouseDown?(CGPoint(x: location.x, y: location.y), event.clickCount)
                return
            }
            rightMouseDownLocation = location
            onRightMouseDown?(CGPoint(x: location.x, y: location.y), event.clickCount)
        }

        override func rightMouseDragged(with event: NSEvent) {
            super.rightMouseDragged(with: event)
            guard let start = rightMouseDownLocation else { return }
            let location = convert(event.locationInWindow, from: nil)
            let translation = CGSize(
                width: location.x - start.x,
                height: location.y - start.y
            )
            onRightMouseDragged?(translation)
        }

        override func rightMouseUp(with event: NSEvent) {
            super.rightMouseUp(with: event)
            rightMouseDownLocation = nil
            onRightMouseUp?()
        }
    }

    func makeNSView(context: Context) -> RepresentedView {
        let view = RepresentedView()
        view.onScroll = onScroll
        view.onMagnify = onMagnify
        view.onRightMouseDown = onRightMouseDown
        view.onRightMouseDragged = onRightMouseDragged
        view.onRightMouseUp = onRightMouseUp

        // Ensure it receives scroll events
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }

        return view
    }

    func updateNSView(_ nsView: RepresentedView, context: Context) {
        nsView.onScroll = onScroll
        nsView.onMagnify = onMagnify
        nsView.onRightMouseDown = onRightMouseDown
        nsView.onRightMouseDragged = onRightMouseDragged
        nsView.onRightMouseUp = onRightMouseUp
    }
}
#endif
