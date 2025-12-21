import Foundation
import Combine
import SwiftUI
import ChromaEngineKit

/// ViewerViewModel
///
/// Owns the *imaging* state for the active volume:
/// - current volume handle
/// - orientation
/// - slice index / slice count
/// - window / level
/// - loading/error flags
///
/// Talks to `ChromaEngineBridge` (an app-level service) to:
/// - load a volume from disk (NIfTI, NRRD, DICOM directory / file)
/// - generate a window/leveled slice for the current state
///
/// Exposes a SwiftUI `Image` (`currentImage`) for the viewer UI to render.
///
/// NOTE: This type does **not** import `ChromaEngineKit` directly; it only
/// sees engine concepts (like `VolumeHandle` and `SliceOrientation`) through
/// app-local typealiases (see `OrientationAliases.swift`) and the bridge API.
@MainActor
final class ViewerViewModel: ObservableObject {

    // MARK: - Imaging state DTO

    /// Internal imaging state. This is intentionally kept private to the
    /// view model so that views only talk to the VM, not to engine types.
    struct ImagingState {
        var volumeHandle: VolumeHandle?
        var orientation: SliceOrientation
        var sliceIndex: Int
        var sliceCount: Int
        var window: Float
        var level: Float
        var isLoading: Bool
        var lastError: String?

        static let empty = ImagingState(
            volumeHandle: nil,
            orientation: .axial,
            sliceIndex: 0,
            sliceCount: 0,
            window: 350,
            level: 40,
            isLoading: false,
            lastError: nil
        )
    }

    // MARK: - Published properties

    /// Core imaging state (volume handle, orientation, slice, WW/L).
    @Published private(set) var imaging: ImagingState = .empty

    /// Render-ready SwiftUI image for the current slice.
    @Published var currentImage: Image?

    // MARK: - Dependencies

    private let engineBridge: ChromaEngineBridge

    // MARK: - Init

    /// Primary initializer used by the app, with dependency injection.
    ///
    /// This is called from `AppContainer` / composition root.
    init(engineBridge: ChromaEngineBridge, initialImagingState: ImagingState = .empty) {
        self.engineBridge = engineBridge
        self.imaging = initialImagingState
    }

    /// Convenience init that uses the default `.empty` imaging state.
    convenience init(engineBridge: ChromaEngineBridge) {
        self.init(engineBridge: engineBridge, initialImagingState: .empty)
    }

    // MARK: - Read-only accessors for the UI

    var hasVolume: Bool { imaging.volumeHandle != nil }
    var orientation: SliceOrientation { imaging.orientation }
    var sliceIndex: Int { imaging.sliceIndex }
    var sliceCount: Int { imaging.sliceCount }
    var window: Float { imaging.window }
    var level: Float { imaging.level }
    var isLoading: Bool { imaging.isLoading }
    var lastError: String? { imaging.lastError }

    // MARK: - Volume loading

    /// Heuristic volume loader: lets the bridge infer the format (NIfTI, NRRD, DICOM, etc.)
    /// from the URL and choose the appropriate IO backend.
    ///
    /// Call this from ImportViewModel or directly after the user picks a file.
    func loadVolume(from url: URL) async {
        imaging.isLoading = true
        imaging.lastError = nil

        do {
            let descriptor = try await engineBridge.loadVolume(from: url)
            installVolume(descriptor)
        } catch {
            imaging.isLoading = false
            imaging.lastError = error.localizedDescription
            currentImage = nil
            print("ViewerViewModel: failed to load volume: \(error)")
        }
    }

    /// Explicit NIfTI loader wrapper in case the Import feature already knows the format.
    /// This assumes `ChromaEngineBridge` exposes `loadNiftiVolume(from:)` and returns
    /// the same `VolumeDescriptor` shape used by `loadVolume(from:)`.
    func loadNiftiVolume(from url: URL) async {
        imaging.isLoading = true
        imaging.lastError = nil

        do {
            let descriptor = try await engineBridge.loadNiftiVolume(from: url)
            installVolume(descriptor)
        } catch {
            imaging.isLoading = false
            imaging.lastError = error.localizedDescription
            currentImage = nil
            print("ViewerViewModel: failed to load NIfTI volume: \(error)")
        }
    }

    /// Explicit NRRD loader wrapper, parallel to NIfTI.
    func loadNRRDVolume(from url: URL) async {
        imaging.isLoading = true
        imaging.lastError = nil

        do {
            let descriptor = try await engineBridge.loadNRRDVolume(from: url)
            installVolume(descriptor)
        } catch {
            imaging.isLoading = false
            imaging.lastError = error.localizedDescription
            currentImage = nil
            print("ViewerViewModel: failed to load NRRD volume: \(error)")
        }
    }

    /// Install a newly loaded volume into the state and refresh the current slice.
    ///
    /// `VolumeDescriptor` is expected to provide at least:
    /// - `handle: VolumeHandle`
    /// - `sizeZ: Int` (for axial slices)
    private func installVolume(_ descriptor: VolumeDescriptor) {
        imaging.volumeHandle = descriptor.handle

        // For now, use Z as the primary slice axis (axial).
        imaging.orientation = .axial

        // Slice count is the extent of the chosen axis; here we assume Z.
        imaging.sliceCount = max(descriptor.sizeZ, 0)

        // Default to the middle slice if possible.
        if imaging.sliceCount > 0 {
            let middle = descriptor.sizeZ / 2
            imaging.sliceIndex = min(
                max(imaging.sliceIndex, 0),
                max(min(middle, imaging.sliceCount - 1), 0)
            )
        } else {
            imaging.sliceIndex = 0
        }

        // Provide sane WW/WL defaults if not already set.
        if imaging.window <= 0 {
            imaging.window = 350
        }
        if imaging.level == 0 {
            imaging.level = 40
        }

        imaging.isLoading = false
        updateSlice()
    }

    // MARK: - Orientation

    func setOrientation(_ orientation: SliceOrientation) {
        guard orientation != imaging.orientation else { return }
        imaging.orientation = orientation
        updateSlice()
    }

    // MARK: - Slice index

    func setSliceIndex(_ index: Int) {
        guard imaging.sliceCount > 0 else { return }

        let clamped = min(max(index, 0), imaging.sliceCount - 1)
        guard clamped != imaging.sliceIndex else { return }

        imaging.sliceIndex = clamped
        updateSlice()
    }

    /// Move relative to the current slice index (e.g. +1, -1, +10).
    func stepSlice(by delta: Int) {
        guard imaging.sliceCount > 0 else { return }

        let newIndex = min(
            max(imaging.sliceIndex + delta, 0),
            imaging.sliceCount - 1
        )

        guard newIndex != imaging.sliceIndex else { return }
        setSliceIndex(newIndex)
    }

    // MARK: - Window / level

    func setWindow(_ window: Float) {
        guard window != imaging.window else { return }
        imaging.window = window
        updateSlice()
    }

    func setLevel(_ level: Float) {
        guard level != imaging.level else { return }
        imaging.level = level
        updateSlice()
    }

    // MARK: - Core slice update

    /// Re-render the current slice based on the latest imaging state.
    ///
    /// This method snapshots the current state and does the expensive work in a `Task`
    /// so that rapid UI changes (slider scrubbing, etc.) don't block the main thread.
    private func updateSlice() {
        let snapshot = imaging

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
                self.imaging.lastError = error.localizedDescription
                print("ViewerViewModel: failed to make slice: \(error)")
            }
        }
    }

    // MARK: - Utility

    /// Convenience reset in case we want to clear the current volume.
    func reset() {
        imaging = .empty
        currentImage = nil
    }
}
