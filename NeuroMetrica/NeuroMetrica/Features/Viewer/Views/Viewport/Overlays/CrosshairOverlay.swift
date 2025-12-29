import SwiftUI

struct CrosshairOverlay: View {
    let contentRect: CGRect
    let position: CGPoint

    private let hitLineWidth: CGFloat = 14

    var body: some View {
        Canvas { context, _ in
            let path = crosshairPath()

            context.clip(to: Path(contentRect))
            context.stroke(
                path,
                with: .color(Color.secondary.opacity(0.5)),
                lineWidth: 1
            )
        }
        .contentShape(crosshairPath().strokedPath(StrokeStyle(lineWidth: hitLineWidth, lineCap: .round)))
    }

    private func crosshairPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: position.x, y: contentRect.minY))
        path.addLine(to: CGPoint(x: position.x, y: contentRect.maxY))
        path.move(to: CGPoint(x: contentRect.minX, y: position.y))
        path.addLine(to: CGPoint(x: contentRect.maxX, y: position.y))
        return path
    }
}
