import AppKit
import CoreImage
import SwiftUI

struct FolderIconRenderer {
    static let canvasSize: CGFloat = 512

    // Figma canvas is 940×940. All coordinates are relative to this.
    private static let figmaCanvas: CGFloat = 940.0

    // MARK: - Public

    static func render(model: FolderIconModel) -> NSImage {
        let size = NSSize(width: canvasSize, height: canvasSize)
        let image = NSImage(size: size)
        image.lockFocus()

        guard let ctx = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }

        let replaceFolder = model.imageReplacesFolder && model.useBackgroundImage && model.backgroundImage != nil
        let showCurrentIcon = model.useCurrentFolderIcon && model.currentFolderIcon != nil && !replaceFolder && !model.useBackgroundImage

        if showCurrentIcon {
            // --- Draw current Finder icon as the base ---
            drawCurrentFolderIcon(ctx: ctx, icon: model.currentFolderIcon!, size: size)
        } else if !replaceFolder {
            let frontColor = NSColor(model.folderTintColor)
            let backColor = NSColor(model.folderBackColor)
            let palette = ColorPalette(front: frontColor, back: backColor)
            let s = canvasSize / figmaCanvas  // scale factor

            // --- Layer 1: Back panel ---
            if let backTemplate = loadTemplate("folder_back") {
                drawBackLayer(ctx: ctx, template: backTemplate, palette: palette, size: size, s: s)
            }

            // --- Glass layout: emojis between back and front ---
            if model.useGlassLayout {
                for glassEmoji in model.glassEmojis where !glassEmoji.emoji.isEmpty {
                    drawGlassEmoji(glassEmoji, in: size)
                }
            }

            // --- Layer 2: Front panel ---
            if let frontTemplate = loadTemplate("folder_front") {
                if model.useGlassLayout {
                    // Glass effect: front panel at reduced height with transparency + rounded corners
                    let frontTop = size.height * (806.0 / figmaCanvas)
                    let glassHeight = frontTop * 0.5
                    let cornerRadius: CGFloat = 30.0 * s
                    let glassRect = CGRect(x: 0, y: 0, width: size.width, height: glassHeight)
                    let roundedPath = CGPath(roundedRect: glassRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
                    ctx.saveGState()
                    ctx.addPath(roundedPath)
                    ctx.clip()
                    ctx.setAlpha(0.55)
                    drawFrontLayer(ctx: ctx, template: frontTemplate, palette: palette, size: size, s: s, skipShadows: true)
                    ctx.restoreGState()
                } else {
                    drawFrontLayer(ctx: ctx, template: frontTemplate, palette: palette, size: size, s: s)
                }
            }
        }

        // --- Background image / replacement image ---
        if model.useBackgroundImage, let bgImage = model.backgroundImage {
            if replaceFolder {
                drawReplacementImage(ctx: ctx, bgImage: bgImage, model: model, size: size)
            } else {
                drawBackgroundImage(ctx: ctx, bgImage: bgImage, model: model, size: size)
            }
        }

        // Text first, then icon on top
        if !model.useGlassLayout && !model.textOverlay.content.isEmpty {
            drawTextOverlay(model.textOverlay, in: size)
        }
        if !model.useGlassLayout && model.iconOverlay.hasContent {
            drawIconOverlay(model.iconOverlay, in: size)
        }

        image.unlockFocus()
        return image
    }

    // MARK: - Color Palette

    struct ColorPalette {
        let backGradientTop: NSColor
        let backGradientBottom: NSColor
        let backBorderTop: NSColor
        let backBorderBottom: NSColor
        let frontGradientTop: NSColor
        let frontGradientBottom: NSColor
        let frontInnerShadowColor: NSColor
        let frontDropShadowColor: NSColor
        let frontBigDropShadowColor: NSColor

        init(front: NSColor, back: NSColor) {
            let f = (front.usingColorSpace(.sRGB) ?? front)
            let b = (back.usingColorSpace(.sRGB) ?? back)

            frontGradientTop = f.blended(withFraction: 0.55, of: .white) ?? f
            frontGradientBottom = f.blended(withFraction: 0.40, of: .white) ?? f

            backGradientTop = b.blended(withFraction: 0.20, of: .white) ?? b
            backGradientBottom = b.blended(withFraction: 0.20, of: .black) ?? b

            backBorderTop = b.blended(withFraction: 0.70, of: .black)?.withAlphaComponent(0.6) ?? b
            backBorderBottom = b.blended(withFraction: 0.70, of: .black)?.withAlphaComponent(0.0) ?? b

            let darkFront = f.blended(withFraction: 0.60, of: .black) ?? f
            frontInnerShadowColor = darkFront.withAlphaComponent(0.35)
            frontDropShadowColor = darkFront.withAlphaComponent(0.20)
            frontBigDropShadowColor = darkFront.withAlphaComponent(0.50)
        }
    }

    // MARK: - Template Loading

    private static var templateCache: [String: CGImage] = [:]

    private static func loadTemplate(_ name: String) -> CGImage? {
        if let cached = templateCache[name] { return cached }
        guard let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "FolderTemplate")
                ?? Bundle.main.url(forResource: name, withExtension: "png"),
              let nsImage = NSImage(contentsOf: url),
              let tiff = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let cg = bitmap.cgImage else {
            return nil
        }
        templateCache[name] = cg
        return cg
    }

    // MARK: - Back Layer

    private static func drawBackLayer(ctx: CGContext, template: CGImage, palette: ColorPalette, size: NSSize, s: CGFloat) {
        let rect = CGRect(origin: .zero, size: size)

        ctx.saveGState()
        ctx.clip(to: rect, mask: template)

        drawGradient(ctx: ctx, rect: rect,
                     topColor: palette.backGradientTop,
                     bottomColor: palette.backGradientBottom)

        if let textureCG = loadTemplate("folder_texture") {
            ctx.setAlpha(0.12)
            ctx.setBlendMode(.multiply)
            let tileSize: CGFloat = 64 * s
            var ty: CGFloat = 0
            while ty < size.height {
                var tx: CGFloat = 0
                while tx < size.width {
                    ctx.draw(textureCG, in: CGRect(x: tx, y: ty, width: tileSize, height: tileSize))
                    tx += tileSize
                }
                ty += tileSize
            }
            ctx.setAlpha(1.0)
            ctx.setBlendMode(.normal)
        }

        let borderWidth = 6.0 * s
        let borderRect = rect.insetBy(dx: borderWidth / 2, dy: borderWidth / 2)
        let borderGrad = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [palette.backBorderTop.cgColor, palette.backBorderBottom.cgColor] as CFArray,
            locations: [0, 1])!

        ctx.setLineWidth(borderWidth)
        ctx.addRect(borderRect)
        ctx.replacePathWithStrokedPath()
        ctx.clip()
        ctx.drawLinearGradient(borderGrad,
                               start: CGPoint(x: rect.midX, y: rect.maxY),
                               end: CGPoint(x: rect.midX, y: rect.minY),
                               options: [])

        ctx.restoreGState()
    }

    // MARK: - Front Layer

    private static func drawFrontLayer(ctx: CGContext, template: CGImage, palette: ColorPalette, size: NSSize, s: CGFloat, skipShadows: Bool = false) {
        let rect = CGRect(origin: .zero, size: size)

        if !skipShadows {
            // Big drop shadow
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0, height: 16 * s),
                           blur: 64 * s,
                           color: palette.frontBigDropShadowColor.cgColor)
            if let frontFill = createMaskedFill(template: template,
                                                 color: palette.frontGradientBottom, size: size) {
                ctx.draw(frontFill, in: rect)
            }
            ctx.restoreGState()
        }

        // Gradient fill clipped to shape
        ctx.saveGState()
        ctx.clip(to: rect, mask: template)
        drawGradient(ctx: ctx, rect: rect,
                     topColor: palette.frontGradientTop,
                     bottomColor: palette.frontGradientBottom)
        ctx.restoreGState()

        // Tiled texture
        if let textureCG = loadTemplate("folder_texture") {
            ctx.saveGState()
            ctx.clip(to: rect, mask: template)
            ctx.setAlpha(0.10)
            ctx.setBlendMode(.multiply)
            let tileSize: CGFloat = 64 * s
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    ctx.draw(textureCG, in: CGRect(x: x, y: y, width: tileSize, height: tileSize))
                    x += tileSize
                }
                y += tileSize
            }
            ctx.restoreGState()
        }

        if !skipShadows {
            // Inner shadow at top
            ctx.saveGState()
            ctx.clip(to: rect, mask: template)
            let frontTopY = size.height * (806.0 / 940.0)
            let shadowDepth = 200.0 * s
            let innerGrad = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [palette.frontInnerShadowColor.cgColor,
                         palette.frontInnerShadowColor.withAlphaComponent(0).cgColor] as CFArray,
                locations: [0, 1])!
            ctx.drawLinearGradient(innerGrad,
                                   start: CGPoint(x: size.width / 2, y: frontTopY),
                                   end: CGPoint(x: size.width / 2, y: frontTopY - shadowDepth),
                                   options: [.drawsAfterEndLocation])
            ctx.restoreGState()
        }

        // NOTE: Bottom highlight stripe removed — it caused a visible line artifact
    }

    /// Create a CGImage that is the template alpha filled with a solid color
    private static func createMaskedFill(template: CGImage, color: NSColor, size: NSSize) -> CGImage? {
        let w = Int(size.width)
        let h = Int(size.height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let maskCtx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                                       bytesPerRow: 0, space: colorSpace,
                                       bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }

        let rect = CGRect(origin: .zero, size: size)
        maskCtx.setFillColor(color.cgColor)
        maskCtx.fill(rect)
        maskCtx.setBlendMode(.destinationIn)
        maskCtx.draw(template, in: rect)

        return maskCtx.makeImage()
    }

    // MARK: - Gradient Helper

    private static func drawGradient(ctx: CGContext, rect: CGRect, topColor: NSColor, bottomColor: NSColor) {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let gradient = CGGradient(colorsSpace: colorSpace,
                                         colors: [topColor.cgColor, bottomColor.cgColor] as CFArray,
                                         locations: [0, 1]) else { return }
        ctx.drawLinearGradient(gradient,
                               start: CGPoint(x: rect.midX, y: rect.maxY),
                               end: CGPoint(x: rect.midX, y: rect.minY),
                               options: [])
    }

    // MARK: - Background Image

    private static func drawBackgroundImage(ctx: CGContext, bgImage: NSImage, model: FolderIconModel, size: NSSize) {
        guard let tiff = bgImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let cgImg = bitmap.cgImage else { return }

        let scale = model.backgroundImageScale
        let imgW = bgImage.size.width * scale
        let imgH = bgImage.size.height * scale
        let drawX = (size.width - imgW) / 2 + model.backgroundImageOffset.x
        let drawY = (size.height - imgH) / 2 + model.backgroundImageOffset.y

        ctx.saveGState()
        let bodyTop = size.height * (806.0 / 940.0)
        ctx.clip(to: CGRect(x: 0, y: 0, width: size.width, height: bodyTop))
        ctx.draw(cgImg, in: CGRect(x: drawX, y: drawY, width: imgW, height: imgH))
        ctx.restoreGState()
    }

    // MARK: - Current Folder Icon (Finder icon as base)

    private static func drawCurrentFolderIcon(ctx: CGContext, icon: NSImage, size: NSSize) {
        guard let tiff = icon.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let cgImg = bitmap.cgImage else { return }

        let rect = CGRect(origin: .zero, size: size)
        ctx.saveGState()
        ctx.draw(cgImg, in: rect)
        ctx.restoreGState()
    }

    // MARK: - Replacement Image (fills entire canvas)

    private static func drawReplacementImage(ctx: CGContext, bgImage: NSImage, model: FolderIconModel, size: NSSize) {
        guard let tiff = bgImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let cgImg = bitmap.cgImage else { return }

        let scale = model.backgroundImageScale
        let imgW = bgImage.size.width * scale
        let imgH = bgImage.size.height * scale
        let drawX = (size.width - imgW) / 2 + model.backgroundImageOffset.x
        let drawY = (size.height - imgH) / 2 + model.backgroundImageOffset.y

        ctx.saveGState()
        ctx.draw(cgImg, in: CGRect(x: drawX, y: drawY, width: imgW, height: imgH))
        ctx.restoreGState()
    }

    // MARK: - Overlays (Icon & Text)

    static func positionPoint(for position: IconPosition, in size: NSSize, overlaySize: NSSize) -> NSPoint {
        let cfg = OverlayPositionConfig.self

        let left   = size.width  * cfg.contentLeft
        let right  = size.width  * cfg.contentRight
        let bottom = size.height * cfg.contentBottom
        let top    = size.height * cfg.contentTop

        let midX = (left + right) / 2 + size.width * cfg.centerOffsetX
        let midY = (bottom + top) / 2 + size.height * cfg.centerOffsetY

        let x: CGFloat
        switch position {
        case .topLeft, .middleLeft, .bottomLeft:
            x = left
        case .topCenter, .center, .bottomCenter:
            x = midX - overlaySize.width / 2
        case .topRight, .middleRight, .bottomRight:
            x = right - overlaySize.width
        }

        let y: CGFloat
        switch position {
        case .bottomLeft, .bottomCenter, .bottomRight:
            y = bottom
        case .middleLeft, .center, .middleRight:
            y = midY - overlaySize.height / 2
        case .topLeft, .topCenter, .topRight:
            y = top - overlaySize.height
        }

        return NSPoint(x: x, y: y)
    }

    private static func overlayDimension(for overlay: IconOverlay, in size: NSSize) -> CGFloat {
        return size.width * overlay.effectiveScaleFactor
    }

    /// Render a text string (emoji or FA unicode) into an NSImage centered in the given size.
    private static func renderTextToImage(_ string: String, font: NSFont, color: NSColor?, size: NSSize) -> NSImage {
        let attrs: [NSAttributedString.Key: Any]
        if let color {
            attrs = [.font: font, .foregroundColor: color]
        } else {
            attrs = [.font: font]
        }
        let str = string as NSString
        let textSize = str.size(withAttributes: attrs)

        let image = NSImage(size: size)
        image.lockFocus()
        let drawX = (size.width - textSize.width) / 2
        let drawY = (size.height - textSize.height) / 2
        str.draw(at: NSPoint(x: drawX, y: drawY), withAttributes: attrs)
        image.unlockFocus()
        return image
    }

    /// Apply outer shadow before drawing content
    private static func applyOuterShadow(dim: CGFloat, intensity: CGFloat = 0.5) {
        let shadow = NSShadow()
        shadow.shadowOffset = NSSize(width: 0, height: -dim * 0.04 * intensity)
        shadow.shadowBlurRadius = dim * 0.08 * intensity
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.35 * intensity)
        shadow.set()
    }

    /// Draw a shape-conforming inner shadow on top of rendered icon content.
    /// The technique: render the icon to get its alpha shape, then draw the
    /// *inverse* (everything outside the shape) with a CG shadow, clipped to
    /// the original shape — the shadow bleeds inward along the shape edges.
    private static func drawShapeInnerShadow(iconImage: NSImage, in drawRect: NSRect, intensity: CGFloat = 0.5) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = Int(iconImage.size.width)
        let h = Int(iconImage.size.height)
        guard w > 0, h > 0 else { return }

        // Get the icon's alpha mask as a CGImage
        guard let tiff = iconImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let iconCG = bitmap.cgImage else { return }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        // 1. Create the "inverse" image: a large opaque rect with the icon shape punched out
        guard let inverseCtx = CGContext(data: nil, width: w, height: h,
                                          bitsPerComponent: 8, bytesPerRow: 0,
                                          space: colorSpace, bitmapInfo: bitmapInfo) else { return }
        let localRect = CGRect(x: 0, y: 0, width: w, height: h)
        // Fill entire rect with opaque black
        inverseCtx.setFillColor(NSColor.black.cgColor)
        inverseCtx.fill(localRect)
        // Punch out the icon shape using destinationOut
        inverseCtx.setBlendMode(.destinationOut)
        inverseCtx.draw(iconCG, in: localRect)

        guard let inverseImage = inverseCtx.makeImage() else { return }

        // 2. Draw the inverse image with a shadow, clipped to the icon shape
        ctx.saveGState()

        // Clip to the icon's alpha shape at the draw position
        ctx.clip(to: drawRect, mask: iconCG)

        // Set inner shadow parameters
        let blur = drawRect.width * 0.06 * intensity
        ctx.setShadow(offset: CGSize(width: 0, height: -blur * 0.4),
                       blur: blur,
                       color: NSColor.black.withAlphaComponent(0.50 * intensity).cgColor)

        // Draw the inverse — the shadow from its edges bleeds inward into the clipped shape
        ctx.draw(inverseImage, in: drawRect)

        // Second pass: subtle highlight from below
        ctx.setShadow(offset: CGSize(width: 0, height: blur * 0.3),
                       blur: blur * 0.5,
                       color: NSColor.white.withAlphaComponent(0.20 * intensity).cgColor)
        ctx.draw(inverseImage, in: drawRect)

        ctx.restoreGState()
    }

    /// Render the icon content to an offscreen NSImage (for inner shadow shape extraction)
    private static func renderIconContent(_ overlay: IconOverlay, dim: CGFloat) -> NSImage? {
        let overlaySize = NSSize(width: dim, height: dim)
        let image = NSImage(size: overlaySize)
        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high

        switch overlay.type {
        case .emoji:
            let font = NSFont.systemFont(ofSize: dim * 0.75)
            let emojiImg = renderTextToImage(overlay.emoji, font: font, color: nil, size: overlaySize)
            emojiImg.draw(in: NSRect(origin: .zero, size: overlaySize))

        case .sfSymbol:
            if let symbolImage = NSImage(systemSymbolName: overlay.sfSymbolName, accessibilityDescription: nil) {
                let config = NSImage.SymbolConfiguration(pointSize: dim * 0.65, weight: .regular)
                let configured = symbolImage.withSymbolConfiguration(config) ?? symbolImage
                let tinted = configured.tinted(with: NSColor(overlay.color))
                let fitRect = aspectFitRect(imageSize: tinted.size,
                                             in: NSRect(origin: .zero, size: overlaySize))
                tinted.draw(in: fitRect)
            }

        case .fontAwesome:
            let faSize = dim * 0.65
            if let parsed = FontAwesomePickerView.parseSelection(overlay.fontAwesomeName) {
                let faFont = FontAwesomePickerView.faFont(size: faSize, style: parsed.style)
                    ?? NSFont.systemFont(ofSize: faSize)
                let faImg = renderTextToImage(parsed.unicode, font: faFont,
                                              color: NSColor(overlay.color), size: overlaySize)
                faImg.draw(in: NSRect(origin: .zero, size: overlaySize))
            }

        case .image:
            let img = overlay.previewImage ?? overlay.customImage
            if let img {
                let fitRect = aspectFitRect(imageSize: img.size,
                                             in: NSRect(origin: .zero, size: overlaySize))
                img.draw(in: fitRect)
            }
        }

        image.unlockFocus()
        return image
    }

    private static func drawGlassEmoji(_ glassEmoji: GlassEmoji, in size: NSSize) {
        let dim = size.width * glassEmoji.sizePreset.scaleFactor
        let overlaySize = NSSize(width: dim, height: dim)

        let font = NSFont.systemFont(ofSize: dim * 0.75)
        let emojiImg = renderTextToImage(glassEmoji.emoji, font: font, color: nil, size: overlaySize)

        var point = positionPoint(for: glassEmoji.position, in: size, overlaySize: overlaySize)
        point.x += glassEmoji.customOffset.x * size.width
        point.y -= glassEmoji.customOffset.y * size.height
        // Same vertical nudge as regular emoji
        point.y -= 25.0 * (size.height / canvasSize)

        let drawRect = NSRect(origin: point, size: overlaySize)

        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()

        // Rotate around the center of the emoji
        let centerX = drawRect.midX
        let centerY = drawRect.midY
        ctx.translateBy(x: centerX, y: centerY)
        ctx.rotate(by: glassEmoji.rotation * .pi / 180)
        ctx.translateBy(x: -centerX, y: -centerY)

        emojiImg.draw(in: drawRect)
        ctx.restoreGState()
    }

    private static func drawIconOverlay(_ overlay: IconOverlay, in size: NSSize) {
        let overlayDim = overlayDimension(for: overlay, in: size)
        let overlaySize = NSSize(width: overlayDim, height: overlayDim)
        var point = positionPoint(for: overlay.position, in: size, overlaySize: overlaySize)
        point.x += overlay.customOffset.x * size.width
        point.y -= overlay.customOffset.y * size.height
        // Default vertical nudge (CG Y up, so subtract to move down)
        if overlay.type == .emoji {
            point.y -= 25.0 * (size.height / canvasSize)
        } else if overlay.type == .sfSymbol || overlay.type == .fontAwesome {
            point.y -= 20.0 * (size.height / canvasSize)
        }
        let drawRect = NSRect(origin: point, size: overlaySize)

        // Render icon content to an offscreen image first
        guard let iconImage = renderIconContent(overlay, dim: overlayDim) else { return }

        let ctx = NSGraphicsContext.current!
        ctx.saveGraphicsState()

        switch overlay.shadowType {
        case .outer:
            applyOuterShadow(dim: overlayDim, intensity: overlay.shadowIntensity)
            iconImage.draw(in: drawRect)
            ctx.restoreGraphicsState()

        case .inner:
            iconImage.draw(in: drawRect)
            ctx.restoreGraphicsState()
            drawShapeInnerShadow(iconImage: iconImage, in: drawRect, intensity: overlay.shadowIntensity)

        case .none:
            iconImage.draw(in: drawRect)
            ctx.restoreGraphicsState()
        }
    }

    private static func textFontSize(for text: TextOverlay, in size: NSSize) -> CGFloat {
        return size.width * text.effectiveScaleFactor * 0.4
    }

    private static func drawTextOverlay(_ text: TextOverlay, in size: NSSize) {
        let fontSize = textFontSize(for: text, in: size)
        let font: NSFont
        let weight = nsWeight(text.fontWeight)
        if text.fontName == "SF Pro" || text.fontName.isEmpty {
            font = NSFont.systemFont(ofSize: fontSize, weight: weight)
        } else if let custom = NSFont(name: text.fontName, size: fontSize) {
            let descriptor = custom.fontDescriptor.addingAttributes([
                .traits: [NSFontDescriptor.TraitKey.weight: weight]
            ])
            font = NSFont(descriptor: descriptor, size: fontSize) ?? custom
        } else {
            font = NSFont.systemFont(ofSize: fontSize, weight: weight)
        }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(text.color),
        ]
        let str = text.content as NSString
        let textSize = str.size(withAttributes: attrs)
        var point = positionPoint(for: text.position, in: size, overlaySize: textSize)
        point.x += text.customOffset.x * size.width
        point.y -= text.customOffset.y * size.height

        // Text margins: 20px left/right, -20px top (on 512 canvas)
        let margin: CGFloat = 20.0 * (size.width / canvasSize)
        switch text.position {
        case .topLeft, .middleLeft, .bottomLeft:
            point.x += margin
        case .topRight, .middleRight, .bottomRight:
            point.x -= margin
        default: break
        }
        switch text.position {
        case .topLeft, .topCenter, .topRight:
            point.y -= margin
        default: break
        }

        // Render text to an offscreen image for shape-aware shadow
        let textImage = NSImage(size: textSize)
        textImage.lockFocus()
        str.draw(at: .zero, withAttributes: attrs)
        textImage.unlockFocus()

        let textRect = NSRect(origin: point, size: textSize)
        let ctx = NSGraphicsContext.current!
        ctx.saveGraphicsState()

        switch text.shadowType {
        case .outer:
            applyOuterShadow(dim: fontSize, intensity: text.shadowIntensity)
            textImage.draw(in: textRect)
            ctx.restoreGraphicsState()

        case .inner:
            textImage.draw(in: textRect)
            ctx.restoreGraphicsState()
            drawShapeInnerShadow(iconImage: textImage, in: textRect, intensity: text.shadowIntensity)

        case .none:
            textImage.draw(in: textRect)
            ctx.restoreGraphicsState()
        }
    }

    /// Fit an image inside a rect preserving aspect ratio, centered.
    private static func aspectFitRect(imageSize: NSSize, in rect: NSRect) -> NSRect {
        guard imageSize.width > 0 && imageSize.height > 0 else { return rect }
        let scale = min(rect.width / imageSize.width, rect.height / imageSize.height)
        let w = imageSize.width * scale
        let h = imageSize.height * scale
        return NSRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h)
    }

    private static func nsWeight(_ weight: Font.Weight) -> NSFont.Weight {
        if weight == .ultraLight { return .ultraLight }
        if weight == .thin { return .thin }
        if weight == .light { return .light }
        if weight == .regular { return .regular }
        if weight == .medium { return .medium }
        if weight == .semibold { return .semibold }
        if weight == .bold { return .bold }
        if weight == .heavy { return .heavy }
        if weight == .black { return .black }
        return .regular
    }
}
