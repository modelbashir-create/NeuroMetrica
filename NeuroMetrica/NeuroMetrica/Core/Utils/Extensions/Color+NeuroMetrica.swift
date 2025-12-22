import SwiftUI

/// Semantic color palette for the NeuroMetrica viewer.
///
/// Keeps PACS-style colors in one place so Canvas/Viewport overlays
/// can stay consistent with HIG and light/dark mode.
struct HeritagePACSTheme {
    // Core surfaces - heritage black for medical imaging (clinically required)
    static let canvasBackground   = Color.black
    static let viewportBackground = Color(red: 0.02, green: 0.02, blue: 0.04)

    // Active viewport accent
    static let activeViewportBorder = Color(red: 0.30, green: 0.80, blue: 0.40)

    // Overlay text
    static let overlayTextPrimary   = Color.white
    static let overlayTextSecondary = Color(white: 0.7)

    // PHI highlight
    static let phiHighlightYellow = Color(red: 1.0, green: 0.86, blue: 0.45)

    // Annotations
    static let crosshairColor   = Color(red: 0.65, green: 0.90, blue: 1.0)
    static let measurementColor = Color(red: 0.10, green: 0.78, blue: 0.88)

    // Status indicators
    static let statusOK      = Color(red: 0.30, green: 0.80, blue: 0.40)
    static let statusWarning = Color(red: 1.00, green: 0.75, blue: 0.30)
    static let statusError   = Color(red: 1.00, green: 0.35, blue: 0.35)
}
