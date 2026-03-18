import SwiftUI

enum IconOverlayType: String, CaseIterable {
    case emoji
    case sfSymbol = "SF Symbol"
    case fontAwesome = "Font Awesome"
    case image
}

enum OverlayShadowType: String, CaseIterable {
    case none = "None"
    case inner = "Inner"
    case outer = "Outer"
}

struct IconOverlay {
    var type: IconOverlayType = .emoji
    var emoji: String = ""
    var sfSymbolName: String = ""
    var fontAwesomeName: String = ""
    var customImage: NSImage?
    /// Downscaled version for preview rendering (auto-generated)
    var previewImage: NSImage?
    var position: IconPosition = .center
    /// Manual drag offset from the grid position (fraction of canvas, -1 to 1)
    var customOffset: CGPoint = .zero
    // nil = using custom slider value; non-nil = using a preset
    var sizePreset: IconSize? = .lg
    var customSizeValue: CGFloat = 256
    var color: Color = .blue
    var shadowType: OverlayShadowType = .none
    var shadowIntensity: CGFloat = 0.5

    var effectiveScaleFactor: CGFloat {
        if let preset = sizePreset {
            return preset.scaleFactor
        }
        return customSizeValue / 512.0
    }

    /// Whether the overlay has content to render (auto-detect, no toggle needed)
    var hasContent: Bool {
        switch type {
        case .emoji: return !emoji.isEmpty
        case .sfSymbol: return !sfSymbolName.isEmpty
        case .fontAwesome: return !fontAwesomeName.isEmpty
        case .image: return customImage != nil
        }
    }

    /// Default shadow type per icon type
    var defaultShadowType: OverlayShadowType {
        .none
    }
}
