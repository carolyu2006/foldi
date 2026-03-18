import SwiftUI

enum LayoutOption: String, CaseIterable, Identifiable {
    case glass = "Glass"
    case left = "Left"
    case right = "Right"
    case emojiOnly = "Emoji"
    case textOnly = "Text"
    case colorOnly = "Blank"

    var id: String { rawValue }

    var imageName: String {
        switch self {
        case .glass: "glass"
        case .left: "left"
        case .right: "right"
        case .emojiOnly: "emoji"
        case .textOnly: "text"
        case .colorOnly: "blank"
        }
    }

    var icon: String {
        switch self {
        case .glass: "sparkles"
        case .left: "text.badge.star"
        case .right: "star.badge.text"
        case .emojiOnly: "face.smiling"
        case .textOnly: "textformat"
        case .colorOnly: "paintbrush.fill"
        }
    }
}

struct CustomizeTabView: View {
    @Bindable var model: FolderIconModel
    @State private var selectedLayout: LayoutOption?

    private var defaultLabel: String {
        if let url = model.selectedFolderURL {
            let name = url.lastPathComponent
            let firstWord = name.components(separatedBy: .whitespaces).first ?? name
            if firstWord.count <= 10 {
                return firstWord.uppercased()
            }
        }
        return "FOLDER"
    }

    private var showEmoji: Bool {
        guard let layout = selectedLayout else { return false }
        return layout == .emojiOnly || layout == .left || layout == .right
    }

    private var showText: Bool {
        guard let layout = selectedLayout else { return false }
        return layout == .textOnly || layout == .left || layout == .right
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Layout")
                    .font(.headline)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(LayoutOption.allCases) { layout in
                            LayoutCard(layout: layout, isSelected: selectedLayout == layout) {
                                selectedLayout = layout
                                applyLayout(layout)
                            }
                        }
                    }
                }

                if selectedLayout != nil {
                    Divider()
                    Text("Folder Color")
                        .font(.headline)
                    // Color combos
                    HStack(spacing: 20) {
                        let isGlass = selectedLayout == .glass
                        let combos = isGlass ? ColorCombo.glassPresets : ColorCombo.presets
                        ForEach(combos) { combo in
                            ColorComboSwatch(combo: combo, isSelected:
                                model.folderBackColor == (Color(hex: combo.bg) ?? .clear) &&
                                model.folderTintColor == (Color(hex: combo.fg) ?? .clear)
                            ) {
                                if isGlass {
                                    model.folderBackColor = Color(hex: combo.bg) ?? .red
                                    model.folderTintColor = Color(hex: combo.fg) ?? .white
                                    model.textOverlay.color = Color(hex: combo.fg) ?? .white
                                    model.useCurrentFolderIcon = false
                                } else {
                                    model.folderBackColor = Color(hex: combo.bg) ?? .red
                                    model.folderTintColor = Color(hex: combo.fg) ?? .white
                                    model.textOverlay.color = Color(hex: combo.bg) ?? .red
                                    model.useCurrentFolderIcon = false
                                }
                                model.forceRender()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // Custom color pickers
                    HStack(spacing: 16) {
                        VStack(spacing: 4) {
                            ShapeColorPicker(color: $model.folderBackColor, shape: .square) {
                                model.textOverlay.color = model.folderBackColor
                                model.useCurrentFolderIcon = false
                                model.forceRender()
                            }
                            Text("Back")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        VStack(spacing: 4) {
                            ShapeColorPicker(color: $model.folderTintColor, shape: .circle) {
                                model.textOverlay.color = model.folderBackColor
                                model.useCurrentFolderIcon = false
                                model.forceRender()
                            }
                            Text("Front")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Glass: 3 separate emoji pickers with position & rotation
                    if selectedLayout == .glass {
                        Divider()
                        Text("Emojis")
                            .font(.headline)
                        GlassEmojiPicker(model: model)
                    }

                    // Text input
                    if showText {
                        Divider()
                        Text("Label")
                            .font(.headline)
                        HStack(spacing: 10) {
                            TextField("Enter text", text: $model.textOverlay.content)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 200)
                                .onChange(of: model.textOverlay.content) { _, _ in
                                    model.forceRender()
                                }
                            ColorPicker("", selection: $model.textOverlay.color, supportsOpacity: false)
                                .labelsHidden()
                                .frame(width: 28, height: 28)
                                .onChange(of: model.textOverlay.color) { _, _ in
                                    model.forceRender()
                                }
                        }
                    }

                    // Icon input (non-glass layouts)
                    if showEmoji {
                        Divider()
                        Text("Icon")
                            .font(.headline)
                        EmojiOnlyPicker(selectedEmoji: $model.iconOverlay.emoji) {
                            model.forceRender()
                        }
                    }
                }
            }
            .padding()
        }
        .onChange(of: model.useCurrentFolderIcon) { _, newValue in
            if newValue {
                selectedLayout = nil
            }
        }
    }

    private func applyLayout(_ layout: LayoutOption) {
        model.useCurrentFolderIcon = false
        model.useBackgroundImage = false
        model.backgroundImage = nil
        model.imageReplacesFolder = false
        model.backgroundImageOffset = .zero
        model.backgroundImageScale = 1.0
        // Switch colors when toggling between glass and non-glass
        let wasGlass = model.useGlassLayout
        model.useGlassLayout = layout == .glass
        if layout == .glass && !wasGlass {
            // Switching to glass: use glass default (light bg, dark fg)
            model.folderBackColor = Color(hex: "F8F8F5") ?? .white
            model.folderTintColor = Color(hex: "A72424") ?? .red
        } else if layout != .glass && wasGlass {
            // Switching from glass: use normal default (dark bg, light fg)
            model.folderBackColor = Color(hex: "A72424") ?? .red
            model.folderTintColor = Color(hex: "F8F8F5") ?? .white
            model.textOverlay.color = Color(hex: "A72424") ?? .red
        }
        switch layout {
        case .glass:
            model.iconOverlay.emoji = ""
            model.textOverlay.content = ""
            // Reset glass emojis to defaults if all empty
            if model.glassEmojis.allSatisfy({ $0.emoji.isEmpty }) {
                model.glassEmojis = [
                    GlassEmoji(emoji: "🎵", position: .middleLeft, customOffset: CGPoint(x: 0.03, y: -0.01), rotation: 15, sizePreset: .lg),
                    GlassEmoji(emoji: "📅", position: .center, customOffset: CGPoint(x: 0, y: -0.12), rotation: 6, sizePreset: .lg),
                    GlassEmoji(emoji: "💻", position: .middleRight, customOffset: CGPoint(x: -0.03, y: -0.01), rotation: -16, sizePreset: .lg),
                ]
            }

        case .left:
            model.iconOverlay.type = .emoji
            model.iconOverlay.position = .middleRight
            model.iconOverlay.sizePreset = .lg
            model.iconOverlay.customOffset = .zero
            model.iconOverlay.customOffset = CGPoint(x: 0, y: 0.05)

            if model.iconOverlay.emoji.isEmpty { model.iconOverlay.emoji = "📅" }
            model.textOverlay.position = .bottomLeft
            model.textOverlay.sizePreset = .md
            model.textOverlay.fontWeight = .bold
            model.textOverlay.customOffset = CGPoint(x: 0, y: -0.08)
            if model.textOverlay.content.isEmpty { model.textOverlay.content = defaultLabel }

        case .right:

            model.iconOverlay.type = .emoji
            model.iconOverlay.position = .middleLeft
            model.iconOverlay.sizePreset = .lg
            model.iconOverlay.customOffset = .zero
            model.iconOverlay.customOffset = CGPoint(x: 0, y: 0.05)
            if model.iconOverlay.emoji.isEmpty { model.iconOverlay.emoji = "📅" }
            model.textOverlay.position = .bottomRight
            model.textOverlay.sizePreset = .md
            model.textOverlay.fontWeight = .bold
            model.textOverlay.customOffset = CGPoint(x: 0, y: -0.08)
            if model.textOverlay.content.isEmpty { model.textOverlay.content = defaultLabel }
        case .emojiOnly:
            model.iconOverlay.type = .emoji
            model.iconOverlay.position = .center
            model.iconOverlay.sizePreset = .xl
            model.iconOverlay.customOffset = .zero
            if model.iconOverlay.emoji.isEmpty { model.iconOverlay.emoji = "📅" }
            model.textOverlay.content = ""

        case .textOnly:
            model.iconOverlay.emoji = ""
            model.textOverlay.position = .bottomCenter
            model.textOverlay.sizePreset = .lg
            model.textOverlay.fontWeight = .bold
            model.textOverlay.customOffset = .zero
            if model.textOverlay.content.isEmpty { model.textOverlay.content = defaultLabel }

        case .colorOnly:
            model.iconOverlay.emoji = ""
            model.textOverlay.content = ""
        }

        model.forceRender()
    }
}

// MARK: - Layout Card

struct LayoutCard: View {
    let layout: LayoutOption
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                LayoutCardImage(imageName: layout.imageName, fallbackIcon: layout.icon)


            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isHovered ? Color.secondary.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .animation(.easeOut(duration: 0.12), value: isSelected)
    }
}

// MARK: - Color Combo

struct ColorCombo: Identifiable {
    let id = UUID()
    let bg: String
    let fg: String

    static let presets: [ColorCombo] = [
        ColorCombo(bg: "A72424", fg: "F8F8F5"),
        ColorCombo(bg: "4B9B3B", fg: "CCF5C4"),
        ColorCombo(bg: "D9AE00", fg: "FFF6D2"),
        ColorCombo(bg: "2B87B9", fg: "C4E7F5"),
        ColorCombo(bg: "8B62CC", fg: "E4D4FF"),
    ]

    // Glass presets: swapped bg/fg for a lighter, translucent look
    static let glassPresets: [ColorCombo] = [
        ColorCombo(bg: "F8F8F5", fg: "A72424"),
        ColorCombo(bg: "CCF5C4", fg: "4B9B3B"),
        ColorCombo(bg: "FFF6D2", fg: "D9AE00"),
        ColorCombo(bg: "C4E7F5", fg: "2B87B9"),
        ColorCombo(bg: "E4D4FF", fg: "8B62CC"),
    ]
}

struct ColorComboSwatch: View {
    let combo: ColorCombo
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(hex: combo.bg) ?? .gray)
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(isHovered ? -15 : 0))
                    .offset(x: isHovered ? 2 : 0)

                Circle()
                    .fill(Color(hex: combo.fg) ?? .white)
                    .frame(width: 32, height: 32)
                    .offset(x: 10, y: 10)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

// MARK: - Shape Color Picker

enum PickerShape {
    case square, circle
}

struct ShapeColorPicker: View {
    @Binding var color: Color
    let shape: PickerShape
    var onChange: () -> Void

    @State private var isHovered = false

    var body: some View {
        ZStack {
            // Hidden ColorPicker to handle the actual picking
            ColorPicker("", selection: $color, supportsOpacity: true)
                .labelsHidden()
                .opacity(0.015)
                .onChange(of: color) { _, _ in onChange() }

            // Visual shape overlay (non-interactive, lets clicks pass through)
            Group {
                switch shape {
                case .square:
                    RoundedRectangle(cornerRadius: 5)
                        .fill(color)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                case .circle:
                    Circle()
                        .fill(color)
                        .overlay(
                            Circle()
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            .frame(width: 36, height: 36)
            .allowsHitTesting(false)
        }
        .frame(width: 38, height: 38)
        .onHover { isHovered = $0 }
        .scaleEffect(isHovered ? 1.08 : 1.0)
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

// MARK: - Layout Card Image

struct LayoutCardImage: View {
    let imageName: String
    let fallbackIcon: String

    var body: some View {
        if let url = Bundle.main.url(forResource: imageName, withExtension: "png"),
           let nsImage = NSImage(contentsOf: url) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 77, height: 77)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.08))
                Image(systemName: fallbackIcon)
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 77, height: 77)
        }
    }
}

// MARK: - Glass Emoji Picker

struct GlassEmojiPicker: View {
    @Bindable var model: FolderIconModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { index in
                    EmojiButton(
                        emoji: model.glassEmojis[index].emoji,
                        size: 48,
                        fontSize: 28
                    ) { picked in
                        model.glassEmojis[index].emoji = picked
                        model.forceRender()
                    }
                }
            }
        }
    }
}
