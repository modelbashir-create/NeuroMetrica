import SwiftUI

struct CrosshairOverlay: View {
    let contentRect: CGRect
    let position: CGPoint
    let horizontalColor: Color
    let verticalColor: Color

    private let hitLineWidth: CGFloat = 14
    private let lineWidth: CGFloat = 1.5
    private let lineOpacity: CGFloat = 0.75

    var body: some View {
        Canvas { context, _ in
            context.clip(to: Path(contentRect))
            context.stroke(
                verticalPath(),
                with: .color(verticalColor.opacity(lineOpacity)),
                lineWidth: lineWidth
            )
            context.stroke(
                horizontalPath(),
                with: .color(horizontalColor.opacity(lineOpacity)),
                lineWidth: lineWidth
            )
        }
        .contentShape(crosshairHitPath().strokedPath(StrokeStyle(lineWidth: hitLineWidth, lineCap: .round)))
    }

    private func verticalPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: position.x, y: contentRect.minY))
        path.addLine(to: CGPoint(x: position.x, y: contentRect.maxY))
        return path
    }

    private func horizontalPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: contentRect.minX, y: position.y))
        path.addLine(to: CGPoint(x: contentRect.maxX, y: position.y))
        return path
    }

    private func crosshairHitPath() -> Path {
        var path = Path()
        path.addPath(verticalPath())
        path.addPath(horizontalPath())
        return path
    }
}
