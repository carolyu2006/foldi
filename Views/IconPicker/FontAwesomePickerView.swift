import SwiftUI

enum FAFontStyle: String, CaseIterable {
    case solid, regular, brands
}

struct FontAwesomePickerView: View {
    @Binding var selection: String
    @State private var searchText = ""
    @State private var selectedStyle: FAFontStyle = .solid

    /// Get the appropriate font for a given style and size
    static func faFont(size: CGFloat, style: FAFontStyle = .solid) -> NSFont? {
        switch style {
        case .solid:
            return NSFont(name: "FontAwesome7Free-Solid", size: size)
        case .regular:
            return NSFont(name: "FontAwesome7Free-Regular", size: size)
        case .brands:
            return NSFont(name: "FontAwesome7Brands-Regular", size: size)
        }
    }

    /// Legacy: try solid first, then regular
    static func faFont(size: CGFloat) -> NSFont? {
        faFont(size: size, style: .solid)
            ?? faFont(size: size, style: .regular)
    }

    /// Parse style and unicode from a selection string like "solid-f007"
    static func parseSelection(_ sel: String) -> (style: FAFontStyle, unicode: String)? {
        let parts = sel.split(separator: "-", maxSplits: 1)
        guard parts.count == 2,
              let style = FAFontStyle(rawValue: String(parts[0])),
              let codepoint = Int(parts[1], radix: 16),
              let scalar = Unicode.Scalar(codepoint) else { return nil }
        return (style, String(scalar))
    }

    private var currentIcons: [FontAwesomeLoader.FAIcon] {
        let icons: [FontAwesomeLoader.FAIcon]
        switch selectedStyle {
        case .solid: icons = FontAwesomeLoader.solidIcons
        case .regular: icons = FontAwesomeLoader.regularIcons
        case .brands: icons = FontAwesomeLoader.brandsIcons
        }
        if searchText.isEmpty { return icons }
        let query = searchText.lowercased()
        return icons.filter { $0.codepointHex.lowercased().contains(query) || $0.id.contains(query) }
    }

    var body: some View {
        VStack(spacing: 8) {
            Picker("Style", selection: $selectedStyle) {
                ForEach(FAFontStyle.allCases, id: \.self) { style in
                    Text(style.rawValue.capitalized).tag(style)
                }
            }
            .pickerStyle(.segmented)

            TextField("Search by hex code...", text: $searchText)
                .textFieldStyle(.roundedBorder)

            let font = Self.faFont(size: 20, style: selectedStyle)

            if font == nil {
                Text("Font not loaded for \(selectedStyle.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }

            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(44)), count: 6), spacing: 6) {
                    ForEach(currentIcons) { icon in
                        VStack(spacing: 2) {
                            if let f = font {
                                Text(icon.unicode)
                                    .font(.init(f))
                            } else {
                                Text(icon.codepointHex)
                                    .font(.system(size: 8).monospaced())
                            }
                        }
                        .frame(width: 40, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selection == icon.id ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.1))
                        )
                        .help(icon.codepointHex)
                        .onTapGesture { selection = icon.id }
                    }
                }
            }
            .frame(maxHeight: 200)

            Text("Selected: \(selection)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
