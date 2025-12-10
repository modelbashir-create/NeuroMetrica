import Foundation
import Combine
import SwiftUI
import ChromaImagingCore

/// ViewerViewModel
///
/// Owns the *imaging* state (`ViewerState`) for the active volume:
/// - current volume handle
/// - orientation
/// - slice index / slice count
/// - window / level
///
/// Talks to `ChromaEngineBridge` to:
/// - load a volume from disk (NIfTI, NRRD, DICOM-directory/file in the future)
/// - generate a window/leveled slice for the current state
///
/// Exposes a SwiftUI `Image` (`currentImage`) for the viewer UI to render.
///
/// NOTE: This is separate from `ViewerLayoutState` (the UI shell state used by `ContentView`).
@MainActor
final class ViewerViewModel: ObservableObject {

    // MARK: - Published state

    /// Core imaging state (volume handle, orientation, slice, WW/L).
    ///
    /// `ViewerState` is a simple data struct (defined in `Core/Features/Viewer/Models/ViewerState.swift`)
    /// that should contain (at minimum):
    /// - `volumeHandle: VolumeHandle?`
    /// - `orientation: SliceOrientation`
    /// - `sliceIndex: Int`
    /// - `sliceCount: Int`
    /// - `window: Float`
    /// - `level: Float`
    /// - `isLoading: Bool`
    /// - `lastError: String?`
    @Published private(set) var state: ViewerState

    /// Render-ready SwiftUI image for the current slice.
    @Published var currentImage: Image?

    // MARK: - Dependencies

    private let engineBridge: ChromaEngineBridge

    // MARK: - Init

    /// Primary initializer used by the app, with dependency injection.
    init(engineBridge: ChromaEngineBridge, initialState: ViewerState = ViewerState()) {
        self.engineBridge = engineBridge
        self.state = initialState
    }

    /// Convenience initializer for previews/dev if needed.
    convenience init() {
        self.init(engineBridge: ChromaEngineBridge())
    }

    // MARK: - Volume loading

    /// Heuristic volume loader: lets the bridge infer the format (NIfTI, NRRD, DICOM, etc.)
    /// from the URL and choose the appropriate IO backend.
    ///
    /// Call this from ImportViewModel or directly after the user picks a file.
    func loadVolume(from url: URL) async {
        state.isLoading = true
        state.lastError = nil

        do {
            let descriptor = try await engineBridge.loadVolume(from: url)
            installVolume(descriptor)
        } catch {
            state.isLoading = false
            state.lastError = error.localizedDescription
            currentImage = nil
            print("ViewerViewModel: failed to load volume: \(error)")
        }
    }

    /// Explicit NIfTI loader wrapper in case the Import feature already knows the format.
    func loadNiftiVolume(from url: URL) async {
        state.isLoading = true
        state.lastError = nil

        do {
            let descriptor = try await engineBridge.loadNiftiVolume(from: url)
            installVolume(descriptor)
        } catch {
            state.isLoading = false
            state.lastError = error.localizedDescription
            currentImage = nil
            print("ViewerViewModel: failed to load NIfTI volume: \(error)")
        }
    }

    /// Install a newly loaded volume into the state and refresh the current slice.
    private func installVolume(_ descriptor: VolumeDescriptor) {
        state.volumeHandle = descriptor.handle

        // For now, use Z as the primary slice axis (axial).
        state.orientation = .axial

        // Slice count is the extent of the chosen axis; here we assume Z.
        state.sliceCount = max(descriptor.sizeZ, 0)

        // Default to the middle slice if possible.
        if state.sliceCount > 0 {
            state.sliceIndex = min(max(state.sliceIndex, 0), state.sliceCount - 1)
        } else {
            state.sliceIndex = 0
        }

        // Provide sane WW/WL defaults if not already set.
        if state.window <= 0 {
            state.window = 350
        }
        if state.level == 0 {
            state.level = 40
        }

        state.isLoading = false
        updateSlice()
    }

    // MARK: - Orientation

    func setOrientation(_ orientation: SliceOrientation) {
        guard orientation != state.orientation else { return }
        state.orientation = orientation
        updateSlice()
    }

    // MARK: - Slice index

    func setSliceIndex(_ index: Int) {
        guard state.sliceCount > 0 else { return }

        let clamped = min(max(index, 0), state.sliceCount - 1)
        guard clamped != state.sliceIndex else { return }

        state.sliceIndex = clamped
        updateSlice()
    }

    /// Move relative to the current slice index (e.g. +1, -1, +10).
    func stepSlice(by delta: Int) {
        guard state.sliceCount > 0 else { return }

        let newIndex = min(
            max(state.sliceIndex + delta, 0),
            state.sliceCount - 1
        )

        guard newIndex != state.sliceIndex else { return }
        setSliceIndex(newIndex)
    }

    // MARK: - Window / level

    func setWindow(_ window: Float) {
        guard window != state.window else { return }
        state.window = window
        updateSlice()
    }

    func setLevel(_ level: Float) {
        guard level != state.level else { return }
        state.level = level
        updateSlice()
    }

    // MARK: - Core slice update

    /// Re-render the current slice based on the latest `state`.
    ///
    /// This method snapshots the current state and does the expensive work in a `Task`
    /// so that rapid UI changes (slider scrubbing, etc.) don't block the main thread.
    private func updateSlice() {
        let snapshot = state

        Task { @MainActor in
            guard let handle = snapshot.volumeHandle else {
                self.currentImage = nil
                return
            }

            do {
                let slice = try await self.engineBridge.makeSlice(
                    from: handle,
                    orientation: snapshot.orientation,
                    index: snapshot.sliceIndex,
                    window: snapshot.window,
                    level: snapshot.level
                )

                // `CIImage2D+Image.swift` provides this helper to get a SwiftUI.Image.
                self.currentImage = slice.toSwiftUIImage()
            } catch {
                self.currentImage = nil
                self.state.lastError = error.localizedDescription
                print("ViewerViewModel: failed to make slice: \(error)")
            }
        }
    }

    // MARK: - Utility

    /// Convenience reset in case we want to clear the current volume.
    func reset() {
        state.volumeHandle = nil
        state.sliceIndex = 0
        state.sliceCount = 0
        currentImage = nil
        state.lastError = nil
    }
}
