import SwiftUI

struct TextOverlay {
    var content: String = ""
    var fontName: String = "SF Pro"
    var fontWeight: Font.Weight = .bold
    var color: Color = Color(hex: "A72424") ?? .red
    var position: IconPosition = .bottomCenter
    /// Manual drag offset from the grid position (fraction of canvas, -1 to 1)
    var customOffset: CGPoint = CGPoint(x: 0, y: -0.049)
    var shadowType: OverlayShadowType = .none
    var shadowIntensity: CGFloat = 0.5
    // nil = using custom slider value; non-nil = using a preset
    var sizePreset: IconSize? = .md
    var customFontSize: CGFloat = 205

    var effectiveScaleFactor: CGFloat {
        if let preset = sizePreset {
            return preset.scaleFactor
        }
        return customFontSize / 512.0
    }
}
