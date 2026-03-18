import Foundation

/// All overlay position constants in one place for easy tweaking.
/// Coordinates are expressed as fractions of the canvas size (0.0–1.0).
/// CG coordinate system: origin at bottom-left, Y increases upward.
enum OverlayPositionConfig {
    // MARK: - Content area bounds (fraction of canvas)
    // These define the region where overlays can be placed on the front panel.

    /// Left edge of content area
    static let contentLeft: CGFloat = 0.00

    /// Right edge of content area
    static let contentRight: CGFloat = 1.00

    /// Bottom edge of content area
    static let contentBottom: CGFloat = 0.12

    /// Top edge of content area
    static let contentTop: CGFloat = 0.80

    // MARK: - Center offsets
    // Shift the visual center to account for folder tab asymmetry.

    /// Horizontal center offset (fraction of width, positive = right)
    static let centerOffsetX: CGFloat = 0.02

    /// Vertical center offset (fraction of height, positive = up)
    static let centerOffsetY: CGFloat = 0.02

    // MARK: - Text margins (in canvas pixels, applied on 512 canvas)
    // Left/right margin = 20px, top margin = -20px (moves top items down)
    // Applied in FolderIconRenderer.drawTextOverlay
}
