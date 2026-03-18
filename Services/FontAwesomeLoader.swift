import AppKit
import CoreText

/// Loads all available Font Awesome icons from the bundled font files at runtime.
enum FontAwesomeLoader {
    struct FAIcon: Identifiable {
        let id: String           // unique key like "solid-f007" or "brands-f09b"
        let unicode: String      // the actual character
        let codepoint: Int       // numeric codepoint for display
        let style: FAFontStyle
        var codepointHex: String { String(format: "%04X", codepoint) }
    }

    /// Cached results
    private static var _solidIcons: [FAIcon]?
    private static var _regularIcons: [FAIcon]?
    private static var _brandsIcons: [FAIcon]?

    static var solidIcons: [FAIcon] {
        if _solidIcons == nil { _solidIcons = loadIcons(style: .solid) }
        return _solidIcons!
    }

    static var regularIcons: [FAIcon] {
        if _regularIcons == nil { _regularIcons = loadIcons(style: .regular) }
        return _regularIcons!
    }

    static var brandsIcons: [FAIcon] {
        if _brandsIcons == nil { _brandsIcons = loadIcons(style: .brands) }
        return _brandsIcons!
    }

    static var allIcons: [FAIcon] {
        solidIcons + regularIcons + brandsIcons
    }

    /// Load all glyphs from a Font Awesome font style
    private static func loadIcons(style: FAFontStyle) -> [FAIcon] {
        guard let font = FontAwesomePickerView.faFont(size: 16, style: style) else {
            return []
        }

        let ctFont = font as CTFont
        let charset = CTFontCopyCharacterSet(ctFont) as CharacterSet

        var icons: [FAIcon] = []

        // FA icons live in Private Use Area: U+E000..U+F8FF and sometimes U+E000..U+EFFF supplementary
        // Also check U+21..U+7E for basic glyphs that FA maps (like +, -, etc.)
        let ranges: [ClosedRange<Int>] = [
            0xE000...0xF8FF,   // BMP Private Use Area
            0xE900...0xEFFF,   // Extended FA range
        ]

        for range in ranges {
            for codepoint in range {
                guard let scalar = Unicode.Scalar(codepoint),
                      charset.contains(scalar) else { continue }

                let char = String(scalar)
                let id = "\(style.rawValue)-\(String(format: "%04x", codepoint))"
                icons.append(FAIcon(id: id, unicode: char, codepoint: codepoint, style: style))
            }
        }

        return icons.sorted { $0.codepoint < $1.codepoint }
    }
}
