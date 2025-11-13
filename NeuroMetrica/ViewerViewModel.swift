import Foundation
import CoreGraphics

@MainActor
final class ViewerViewModel: ObservableObject {
    // Dependencies
    private let studyBrowser: StudyBrowser
    private let slicer: SliceGenerator

    // State
    @Published var study: Study?
    @Published var selectedSeries: Series?
    @Published var orientation: VolumeOrientation = .axial
    @Published var sliceIndex: Int = 0
    @Published var window: Float = 80
    @Published var level: Float = 40
    @Published var displayedSlice: CGImage?
    @Published var errorMessage: String?

    @Published var annotations: [Annotation] = []
    @Published var activeDistanceAnnotation: DistanceAnnotation?

    init(studyBrowser: StudyBrowser, slicer: SliceGenerator) {
        self.studyBrowser = studyBrowser
        self.slicer = slicer
    }

    func loadDemo() {
        do {
            let s = try studyBrowser.loadDemoStudy()
            study = s
            selectedSeries = s.series.first
            orientation = .axial
            sliceIndex = 0
            window = 80
            level = 40
            annotations = []
            activeDistanceAnnotation = nil
            updateSlice()
        } catch {
            errorMessage = "Failed to load study: \(error.localizedDescription)"
        }
    }

    private var currentVolume: Volume3D<Int16>? {
        selectedSeries?.volumes.first
    }

    func updateSlice() {
        guard let volume = currentVolume else { return }

        let maxIndex: Int
        switch orientation {
        case .axial:    maxIndex = volume.size.z - 1
        case .coronal:  maxIndex = volume.size.y - 1
        case .sagittal: maxIndex = volume.size.x - 1
        }
        sliceIndex = min(max(sliceIndex, 0), maxIndex)

        displayedSlice = slicer.makeSlice(
            from: volume,
            orientation: orientation,
            index: sliceIndex,
            window: window,
            level: level
        )
    }

    func stepSlice(by delta: Int) {
        sliceIndex += delta
        updateSlice()
    }

    func changeOrientation(to newOrientation: VolumeOrientation) {
        orientation = newOrientation
        updateSlice()
    }

    func adjustWindowLevel(window: Float, level: Float) {
        self.window = window
        self.level = level
        updateSlice()
    }

    // MARK: - Distance measurement (normalized coordinates)

    func startDistance(at point: CGPoint, in size: CGSize) {
        let norm = normalize(point: point, in: size)
        let p = SIMD2<Float>(Float(norm.x), Float(norm.y))
        activeDistanceAnnotation = DistanceAnnotation(
            sliceIndex: sliceIndex,
            orientation: orientation,
            p1: p,
            p2: p,
            lengthMm: nil
        )
    }

    func updateDistance(to point: CGPoint, in size: CGSize) {
        guard var ann = activeDistanceAnnotation else { return }
        let norm = normalize(point: point, in: size)
        ann.p2 = SIMD2<Float>(Float(norm.x), Float(norm.y))
        activeDistanceAnnotation = ann
    }

    func endDistance() {
        if let ann = activeDistanceAnnotation {
            annotations.append(.distance(ann))
        }
        activeDistanceAnnotation = nil
    }

    private func normalize(point: CGPoint, in size: CGSize) -> CGPoint {
        guard size.width > 0, size.height > 0 else { return .zero }
        return CGPoint(x: point.x / size.width,
                       y: point.y / size.height)
    }
}