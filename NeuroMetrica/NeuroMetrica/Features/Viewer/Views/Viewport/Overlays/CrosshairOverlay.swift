import SwiftUI

struct CrosshairOverlay: View {
    let size: CGSize

    var body: some View {
        Canvas { context, _ in
            let midX = size.width / 2
            let midY = size.height / 2

            var path = Path()
            path.move(to: CGPoint(x: midX, y: 0))
            path.addLine(to: CGPoint(x: midX, y: size.height))
            path.move(to: CGPoint(x: 0, y: midY))
            path.addLine(to: CGPoint(x: size.width, y: midY))

            context.stroke(
                path,
                with: .color(HeritagePACSTheme.crosshairColor.opacity(0.5)),
                lineWidth: 1
            )
        }
    }
}
