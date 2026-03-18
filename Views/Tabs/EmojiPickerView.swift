import SwiftUI
import UniformTypeIdentifiers

enum IconPickerMode: String, CaseIterable {
    case emoji = "Emoji"
    case sfSymbol = "Symbol"
    case upload = "Upload"
}

struct IconPickerView: View {
    @Bindable var model: FolderIconModel
    var onChange: () -> Void

    @State private var mode: IconPickerMode = .emoji
    @State private var searchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Mode picker
            Picker("", selection: $mode) {
                ForEach(IconPickerMode.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
            .onChange(of: mode) { _, newMode in
                switch newMode {
                case .emoji:
                    model.iconOverlay.type = .emoji
                case .sfSymbol:
                    model.iconOverlay.type = .sfSymbol
                    model.iconOverlay.color = model.folderBackColor.lighter(by: 0.3)
                case .upload:
                    model.iconOverlay.type = .image
                }
                onChange()
            }

            // Selected preview (left) + picker grid (right)
            HStack(alignment: .top, spacing: 16) {
                // Selected preview
                VStack(spacing: 4) {
                    switch mode {
                    case .emoji:
                        if !model.iconOverlay.emoji.isEmpty {
                            Text(model.iconOverlay.emoji)
                                .font(.system(size: 48))
                                .frame(width: 64, height: 64)
                        } else {
                            placeholderPreview
                        }
                    case .sfSymbol:
                        VStack(spacing: 6) {
                            if !model.iconOverlay.sfSymbolName.isEmpty {
                                Image(systemName: model.iconOverlay.sfSymbolName)
                                    .font(.system(size: 36))
                                    .foregroundStyle(model.iconOverlay.color)
                                    .frame(width: 64, height: 64)
                            } else {
                                placeholderPreview
                            }
                            ColorPicker("", selection: $model.iconOverlay.color, supportsOpacity: false)
                                .labelsHidden()
                                .frame(width: 28, height: 28)
                                .onChange(of: model.iconOverlay.color) { _, _ in
                                    onChange()
                                }
                        }
                    case .upload:
                        if let img = model.iconOverlay.customImage {
                            Image(nsImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 64, height: 64)
                        } else {
                            placeholderPreview
                        }
                    }
                }
                .frame(width: 64)

                // Picker content
                VStack(alignment: .leading, spacing: 6) {
                    switch mode {
                    case .emoji:
                        emojiPicker
                    case .sfSymbol:
                        sfSymbolPicker
                    case .upload:
                        uploadPicker
                    }
                }
            }
        }
    }

    private var placeholderPreview: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.secondary.opacity(0.1))
            .frame(width: 64, height: 64)
            .overlay {
                Image(systemName: "questionmark")
                    .foregroundStyle(.secondary)
            }
    }

    // MARK: - Emoji Picker

    private var emojiPicker: some View {
        EmojiButton(emoji: model.iconOverlay.emoji, size: 52, fontSize: 36) { picked in
            model.iconOverlay.emoji = picked
            onChange()
        }
    }

    // MARK: - SF Symbol Picker

    private let symbols = [
        "star.fill", "heart.fill", "folder.fill", "doc.fill", "gear",
        "house.fill", "music.note", "photo", "video", "gamecontroller.fill",
        "paintbrush.fill", "hammer.fill", "wrench.fill", "scissors",
        "book.fill", "bookmark.fill", "flag.fill", "bell.fill", "tag.fill",
        "bolt.fill", "flame.fill", "leaf.fill", "drop.fill", "snowflake",
        "sun.max.fill", "moon.fill", "cloud.fill", "globe", "map.fill",
        "lock.fill", "key.fill", "shield.fill", "eye.fill", "hand.thumbsup.fill",
        "person.fill", "crown.fill", "trophy.fill", "gift.fill", "cart.fill",
        "cpu", "desktopcomputer", "terminal.fill", "externaldrive.fill",
    ]

    private var filteredSymbols: [String] {
        if searchText.isEmpty { return symbols }
        return symbols.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    private var sfSymbolPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Search symbols...", text: $searchText)
                .textFieldStyle(.roundedBorder)

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 36), spacing: 6)], spacing: 6) {
                    ForEach(filteredSymbols, id: \.self) { name in
                        Button {
                            model.iconOverlay.sfSymbolName = name
                            onChange()
                        } label: {
                            Image(systemName: name)
                                .font(.title3)
                                .frame(width: 32, height: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(model.iconOverlay.sfSymbolName == name ? Color.accentColor.opacity(0.3) : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(height: 250)
        }
    }

    // MARK: - Upload Picker

    private var uploadPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            if model.iconOverlay.customImage != nil {
                Button("Remove") {
                    model.iconOverlay.customImage = nil
                    model.iconOverlay.previewImage = nil
                    onChange()
                }
            }

            Button("Choose Image...") {
                let panel = NSOpenPanel()
                panel.allowedContentTypes = [.image]
                panel.allowsMultipleSelection = false
                if panel.runModal() == .OK, let url = panel.url {
                    let original = NSImage(contentsOf: url)
                    model.iconOverlay.customImage = original
                    model.iconOverlay.previewImage = original.flatMap { downscale($0, maxDim: 512) }
                    onChange()
                }
            }
        }
    }

    private func downscale(_ image: NSImage, maxDim: CGFloat) -> NSImage {
        let w = image.size.width
        let h = image.size.height
        guard max(w, h) > maxDim else { return image }
        let scale = maxDim / max(w, h)
        let newSize = NSSize(width: w * scale, height: h * scale)
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize))
        newImage.unlockFocus()
        return newImage
    }
}
