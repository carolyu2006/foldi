import SwiftUI

struct AISuggestion: Codable {
    let themeColor: String?
    let frontColor: String?   // fallback if LLM returns old format
    let backColor: String?    // accepted to prevent decode failure
    let text: TextSuggestion?
    let icon: IconSuggestion?

    var resolvedThemeColor: String {
        themeColor ?? frontColor ?? "#4A90D9"
    }

    struct TextSuggestion: Codable {
        let content: String?
        let position: String?
        let size: String?
        let color: String?
        let font: String?
        let weight: String?
    }

    struct IconSuggestion: Codable {
        let emoji: String?
        let sfSymbol: String?
        let fontAwesome: String?
        let priority: [String]?
        let position: String?
        let size: String?
    }

    // MARK: - Apply to model

    func apply(to model: FolderIconModel) {
        // 1. Theme color → derive front/back + icon/text colors via applyBaseColor
        let themeNSColor: NSColor
        if let color = Color(hex: resolvedThemeColor) {
            themeNSColor = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
            model.applyBaseColor(color)
        } else {
            themeNSColor = NSColor.blue
        }
        let darkerColor = Color(themeNSColor.blended(withFraction: 0.25, of: .black) ?? themeNSColor)

        // 2. Text
        if let t = text {
            if let content = t.content, !content.isEmpty {
                // Limit to max 2 words
                let words = content.split(separator: " ").prefix(2)
                let trimmed = words.joined(separator: " ")
                model.textOverlay.content = trimmed
                // Auto-size: 1 word → M, 2 words → S
                model.textOverlay.sizePreset = words.count >= 2 ? .sm : .md
            }
            if let pos = t.position, let p = IconPosition.fromJSON(pos) {
                model.textOverlay.position = p
            }
            model.textOverlay.customOffset = CGPoint(x: 0, y: -0.049)
            // Text color = back color (same as icon), matching the theme
            model.textOverlay.color = darkerColor
            if let font = t.font, !font.isEmpty {
                model.textOverlay.fontName = font
            }
            if let weight = t.weight {
                model.textOverlay.fontWeight = Font.Weight.fromJSON(weight)
            }
            model.textOverlay.shadowType = .none
            print("[AI Designer] Text applied: content='\(model.textOverlay.content)' size=\(model.textOverlay.sizePreset?.rawValue ?? "nil")")
        } else {
            print("[AI Designer] No text in suggestion")
        }

        // 3. Icon — load all three, activate by priority
        if let i = icon {
            // Store all three options
            if let emoji = i.emoji, !emoji.isEmpty {
                model.iconOverlay.emoji = emoji
            }
            if let sfName = i.sfSymbol, !sfName.isEmpty {
                model.iconOverlay.sfSymbolName = sfName
            }
            if let faName = i.fontAwesome, !faName.isEmpty,
               let faID = FontAwesomeMap.lookup(faName) {
                model.iconOverlay.fontAwesomeName = faID
            }

            // Determine active type by priority
            let order = i.priority ?? ["emoji", "sfSymbol", "fontAwesome"]
            var activated = false
            for choice in order {
                switch choice {
                case "fontAwesome":
                    if !model.iconOverlay.fontAwesomeName.isEmpty {
                        model.iconOverlay.type = .fontAwesome
                        activated = true
                    }
                case "sfSymbol":
                    if !model.iconOverlay.sfSymbolName.isEmpty,
                       NSImage(systemSymbolName: model.iconOverlay.sfSymbolName,
                               accessibilityDescription: nil) != nil {
                        model.iconOverlay.type = .sfSymbol
                        activated = true
                    }
                case "emoji":
                    if !model.iconOverlay.emoji.isEmpty {
                        model.iconOverlay.type = .emoji
                        activated = true
                    }
                default:
                    break
                }
                if activated { break }
            }

            if let pos = i.position, let p = IconPosition.fromJSON(pos) {
                model.iconOverlay.position = p
            }
            if let size = i.size, let s = IconSize.fromJSON(size) {
                model.iconOverlay.sizePreset = s
            }

            // Icon color = darker shade of theme (same as back color)
            model.iconOverlay.color = darkerColor
            model.iconOverlay.shadowType = .none
        }

        model.hasUnsavedChanges = true
        model.forceRender()
    }

    // MARK: - Parse from LLM response

    static func parse(from response: String) throws -> AISuggestion {
        var json = response.trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip markdown code fences if present
        if json.hasPrefix("```") {
            let lines = json.components(separatedBy: .newlines)
            let stripped = lines.drop { $0.hasPrefix("```") }
                                .reversed().drop { $0.hasPrefix("```") }.reversed()
            json = stripped.joined(separator: "\n")
        }
        guard let data = json.data(using: .utf8) else {
            throw LLMError.noResponse
        }
        let decoded = try JSONDecoder().decode(AISuggestion.self, from: data)
        print("[AI Designer] Parsed JSON — theme: \(decoded.resolvedThemeColor), text: \(decoded.text?.content ?? "nil"), icon emoji: \(decoded.icon?.emoji ?? "nil")")
        return decoded
    }
}

// MARK: - Font Awesome Name → ID Mapping

enum FontAwesomeMap {
    /// Maps common FA icon names to their codepoint IDs (style-hex format).
    /// This is a curated subset of the most useful icons for folder categorization.
    private static let map: [String: String] = [
        // Development
        "code": "solid-f121",
        "terminal": "solid-f120",
        "bug": "solid-f188",
        "database": "solid-f1c0",
        "server": "solid-f233",
        "microchip": "solid-f2db",
        "robot": "solid-f544",
        "laptop-code": "solid-f5fc",

        // Brands
        "github": "brands-f09b",
        "python": "brands-f3e2",  // note: FA7 may differ
        "js": "brands-f3b8",
        "java": "brands-f4e4",
        "react": "brands-f41b",
        "apple": "brands-f179",
        "android": "brands-f17b",
        "docker": "brands-f395",
        "git": "brands-f1d3",
        "npm": "brands-f3d4",
        "swift": "brands-f8e1",
        "rust": "brands-e07a",

        // Files & Documents
        "file": "solid-f15b",
        "file-code": "solid-f1c9",
        "file-pdf": "solid-f1c1",
        "file-image": "solid-f1c5",
        "file-video": "solid-f1c8",
        "file-audio": "solid-f1c7",
        "file-archive": "solid-f1c6",
        "folder": "solid-f07b",
        "folder-open": "solid-f07c",
        "book": "solid-f02d",
        "bookmark": "solid-f02e",

        // Media
        "music": "solid-f001",
        "film": "solid-f008",
        "camera": "solid-f030",
        "image": "solid-f03e",
        "video": "solid-f03d",
        "headphones": "solid-f025",
        "microphone": "solid-f130",
        "palette": "solid-f53f",
        "paint-brush": "solid-f1fc",
        "pen": "solid-f304",

        // Science & Education
        "flask": "solid-f0c3",
        "atom": "solid-f5d2",
        "microscope": "solid-f610",
        "graduation-cap": "solid-f19d",
        "brain": "solid-f5dc",
        "lightbulb": "solid-f0eb",
        "calculator": "solid-f1ec",
        "chart-bar": "solid-f080",
        "chart-line": "solid-f201",
        "chart-pie": "solid-f200",

        // Business & Finance
        "briefcase": "solid-f0b1",
        "dollar-sign": "solid-f155",
        "credit-card": "solid-f09d",
        "shopping-cart": "solid-f07a",
        "store": "solid-f54e",
        "building": "solid-f1ad",
        "handshake": "solid-f2b5",
        "receipt": "solid-f543",

        // Communication
        "envelope": "solid-f0e0",
        "comment": "solid-f075",
        "comments": "solid-f086",
        "phone": "solid-f095",
        "paper-plane": "solid-f1d8",
        "bell": "solid-f0f3",

        // Travel & Places
        "plane": "solid-f072",
        "car": "solid-f1b9",
        "map": "solid-f279",
        "globe": "solid-f0ac",
        "compass": "solid-f14e",
        "home": "solid-f015",
        "mountain": "solid-f6fc",
        "tree": "solid-f1bb",
        "umbrella-beach": "solid-f5ca",

        // Health & Fitness
        "heart": "solid-f004",
        "heartbeat": "solid-f21e",
        "medkit": "solid-f0fa",
        "dumbbell": "solid-f44b",
        "running": "solid-f70c",
        "bicycle": "solid-f206",

        // Gaming
        "gamepad": "solid-f11b",
        "dice": "solid-f522",
        "puzzle-piece": "solid-f12e",
        "chess": "solid-f439",

        // Security
        "lock": "solid-f023",
        "shield-alt": "solid-f3ed",
        "key": "solid-f084",
        "user-shield": "solid-f505",

        // Misc
        "star": "solid-f005",
        "fire": "solid-f06d",
        "bolt": "solid-f0e7",
        "cog": "solid-f013",
        "wrench": "solid-f0ad",
        "tools": "solid-f7d9",
        "download": "solid-f019",
        "upload": "solid-f093",
        "cloud": "solid-f0c2",
        "gift": "solid-f06b",
        "trash": "solid-f1f8",
        "clock": "solid-f017",
        "calendar": "solid-f133",
        "flag": "solid-f024",
        "tag": "solid-f02b",
        "search": "solid-f002",
        "link": "solid-f0c1",
        "list": "solid-f03a",
        "check": "solid-f00c",
        "times": "solid-f00d",
        "plus": "solid-f067",
        "minus": "solid-f068",
        "info-circle": "solid-f05a",
        "question-circle": "solid-f059",
        "exclamation-triangle": "solid-f071",
    ]

    static func lookup(_ name: String) -> String? {
        let key = name.lowercased()
            .replacingOccurrences(of: "fa-", with: "")
            .replacingOccurrences(of: "fas-", with: "")
            .replacingOccurrences(of: "fab-", with: "")
        return map[key]
    }

    static var availableNames: [String] {
        map.keys.sorted()
    }
}

// MARK: - Helpers

extension Color {
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let int = UInt64(h, radix: 16) else { return nil }
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    /// Returns a lighter version of this color by blending toward white.
    func lighter(by amount: CGFloat = 0.3) -> Color {
        let ns = NSColor(self)
        guard let rgb = ns.usingColorSpace(.sRGB) else { return self }
        let r = min(rgb.redComponent + amount, 1.0)
        let g = min(rgb.greenComponent + amount, 1.0)
        let b = min(rgb.blueComponent + amount, 1.0)
        return Color(red: r, green: g, blue: b)
    }
}

extension IconPosition {
    static func fromJSON(_ s: String) -> IconPosition? {
        IconPosition(rawValue: s)
    }
}

extension IconSize {
    static func fromJSON(_ s: String) -> IconSize? {
        switch s.lowercased() {
        case "xs": return .xs
        case "sm", "s": return .sm
        case "md", "m", "medium": return .md
        case "lg", "l", "large": return .lg
        case "xl": return .xl
        case "xxl": return .xxl
        default: return nil
        }
    }
}

extension Font.Weight {
    static func fromJSON(_ s: String) -> Font.Weight {
        switch s.lowercased() {
        case "regular": .regular
        case "medium": .medium
        case "medium": .medium
        case "medium": .medium
        case "heavy": .heavy
        case "light": .light
        case "thin": .thin
        default: .medium
        }
    }
}
