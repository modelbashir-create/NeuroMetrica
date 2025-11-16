import Foundation
import Combine
import SwiftUI
import ChromaImagingKit

@MainActor
final class ViewerViewModel: ObservableObject {

    // MARK: - Published state

    @Published private(set) var state: ViewerState = .empty()
    @Published var currentImage: Image?

    // MARK: - Dependencies

    private let engineBridge: ChromaEngineBridge

    /// Primary initializer used by the app, with dependency injection
    init(engineBridge: ChromaEngineBridge) {
        self.engineBridge = engineBridge
    }

    /// Convenience initializer for previews/dev if needed
    convenience init() {
        self.init(engineBridge: ChromaEngineBridge())
    }

    // MARK: - Volume

    /// Load a NIfTI volume from disk via the engine bridge and update the viewer state.
    /// This is the main entry point the UI should call after the user picks a file.
    func loadNIfTIVolume(from url: URL) async {
        do {
            let volume = try await engineBridge.loadNIfTI(from: url)
            // We are already on @MainActor for this type, so this is safe and simple.
            setVolume(volume)
        } catch {
            // TODO: route through AppLogger / AppError once we have global error handling.
            print("ViewerViewModel: failed to load NIfTI volume: \(error)")
            // Optionally clear current image/state on failure
            state = .empty()
            currentImage = nil
        }
    }

    func setVolume(_ volume: CIImageVolume) {
        state = state.updating(volume: volume)
        updateSlice()
    }

    // MARK: - Orientation

    func setOrientation(_ orientation: SliceOrientation) {
        guard orientation != state.orientation else { return }
        state = state.updating(volume: state.volume, orientation: orientation)
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

        // Avoid unnecessary work if nothing changes
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

    private func updateSlice() {
        // Snapshot current state so we don't race if it changes again quickly.
        let snapshot = state

        Task { @MainActor in
            guard let volume = snapshot.volume else {
                self.currentImage = nil
                return
            }

            do {
                let slice = try self.engineBridge.makeSlice(
                    volume: volume,
                    orientation: snapshot.orientation,
                    index: snapshot.sliceIndex,
                    window: snapshot.window,
                    level: snapshot.level
                )

                self.currentImage = slice.toSwiftUIImage()
            } catch {
                // TODO: route through AppLogger / AppError later
                print("ViewerViewModel: failed to make slice: \(error)")
                self.currentImage = nil
            }
        }
    }
}
