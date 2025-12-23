import SwiftUI

struct MeasurementOverlay: View {
    let size: CGSize

    var body: some View {
        Canvas { context, _ in
            var path = Path()
            path.move(to: CGPoint(x: size.width * 0.2, y: size.height * 0.75))
            path.addLine(to: CGPoint(x: size.width * 0.7, y: size.height * 0.35))

            context.stroke(
                path,
                with: .color(HeritagePACSTheme.measurementColor),
                style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
            )
        }
    }
}
