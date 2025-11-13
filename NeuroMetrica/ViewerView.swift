//
//  ViewerView.swift
//  NeuroMetrica
//
//  Created by Mohamed Elbashir on 11/12/25.
//

import SwiftUI

struct ViewerView: View {
    @StateObject var viewModel: ViewerViewModel

    var body: some View {
        VStack(spacing: 0) {
            header

            GeometryReader { geo in
                ZStack {
                    if let image = viewModel.displayedSlice {
                        Image(decorative: image,
                              scale: 1.0,
                              orientation: .up)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black)
                            .gesture(sliceScrollGesture)
                            .gesture(distanceGesture(in: geo.size))
                    } else if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                    } else {
                        Text("Loading…")
                            .foregroundColor(.secondary)
                    }

                    DistanceOverlayView(
                        active: viewModel.activeDistanceAnnotation,
                        annotations: viewModel.annotations
                    )
                }
            }

            controls
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .onAppear {
            viewModel.loadDemo()
        }
    }

    // MARK: - UI pieces

    private var header: some View {
        HStack {
            if let summary = viewModel.study?.summary {
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.patientName)
                        .font(.headline)
                    Text(summary.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(summary.modalitySummary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("Neurometrica")
                    .font(.headline)
            }
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private var controls: some View {
        VStack(spacing: 8) {
            OrientationPicker(
                orientation: viewModel.orientation,
                onChange: { newOrientation in
                    viewModel.changeOrientation(to: newOrientation)
                }
            )

            SliceControls(
                sliceIndex: viewModel.sliceIndex,
                onStep: { delta in
                    viewModel.stepSlice(by: delta)
                }
            )

            WindowLevelControls(
                window: Double(viewModel.window),
                level: Double(viewModel.level),
                onChange: { w, l in
                    viewModel.adjustWindowLevel(window: Float(w), level: Float(l))
                }
            )
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    // MARK: - Gestures

    /// Drag up/down to scroll slices.
    private var sliceScrollGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                let delta = Int(-value.translation.height / 5)
                if delta != 0 {
                    viewModel.stepSlice(by: delta)
                }
            }
    }

    /// Tap-drag to draw a distance line.
    private func distanceGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if viewModel.activeDistanceAnnotation == nil {
                    viewModel.startDistance(at: value.startLocation, in: size)
                }
                viewModel.updateDistance(to: value.location, in: size)
            }
            .onEnded { _ in
                viewModel.endDistance()
            }
    }
}

// MARK: - Small subviews (keep in same file to avoid extra files)

struct OrientationPicker: View {
    let orientation: VolumeOrientation
    let onChange: (VolumeOrientation) -> Void

    var body: some View {
        Picker("Orientation", selection: Binding(
            get: { orientation },
            set: { onChange($0) }
        )) {
            Text("Axial").tag(VolumeOrientation.axial)
            Text("Coronal").tag(VolumeOrientation.coronal)
            Text("Sagittal").tag(VolumeOrientation.sagittal)
        }
        .pickerStyle(.segmented)
    }
}

struct SliceControls: View {
    let sliceIndex: Int
    let onStep: (Int) -> Void

    var body: some View {
        HStack {
            Text("Slice: \(sliceIndex)")
                .font(.subheadline)
            Spacer()
            Button("−") { onStep(-1) }
            Button("+") { onStep(1) }
        }
    }
}

struct WindowLevelControls: View {
    let window: Double
    let level: Double
    let onChange: (Double, Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Window: \(Int(window))  Level: \(Int(level))")
                .font(.caption)

            Slider(value: Binding(
                get: { window },
                set: { onChange($0, level) }
            ), in: 20...200)

            Slider(value: Binding(
                get: { level },
                set: { onChange(window, $0) }
            ), in: -50...150)
        }
    }
}

// MARK: - Distance overlay

struct DistanceOverlayView: View {
    let active: DistanceAnnotation?
    let annotations: [Annotation]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(distanceAnnotations, id: \.id) { ann in
                    line(for: ann, in: geo.size)
                        .stroke(Color.green, lineWidth: 2)
                }

                if let active = active {
                    line(for: active, in: geo.size)
                        .stroke(Color.yellow, style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var distanceAnnotations: [DistanceAnnotation] {
        annotations.compactMap {
            if case .distance(let d) = $0 { return d }
            return nil
        }
    }

    private func line(for ann: DistanceAnnotation, in size: CGSize) -> Path {
        var path = Path()
        let p1 = CGPoint(x: CGFloat(ann.p1.x) * size.width,
                         y: CGFloat(ann.p1.y) * size.height)
        let p2 = CGPoint(x: CGFloat(ann.p2.x) * size.width,
                         y: CGFloat(ann.p2.y) * size.height)
        path.move(to: p1)
        path.addLine(to: p2)
        return path
    }
}
