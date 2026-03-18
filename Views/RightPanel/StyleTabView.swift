import SwiftUI
import UniformTypeIdentifiers

struct StyleTabView: View {
    @Bindable var model: FolderIconModel

    private let presetColors: [Color] = [
        .blue, .indigo, .purple, .pink, .red, .orange,
        .yellow, .green, .mint, .teal, .cyan, .brown, .gray,
    ]

    @State private var isDropTargeted = false

    var body: some View {
        Form {
            Section("Folder Color") {
                ColorPicker("Front Color", selection: $model.folderTintColor, supportsOpacity: true)
                    .onChange(of: model.folderTintColor) { model.useCurrentFolderIcon = false }
                ColorPicker("Back Color", selection: $model.folderBackColor, supportsOpacity: true)
                    .onChange(of: model.folderBackColor) { model.useCurrentFolderIcon = false }
            }

            Section("Quick Colors") {
                ColorSwatchGrid(colors: presetColors) { baseColor in
                    model.applyBaseColor(baseColor)
                }
            }

            Section("Background Image") {
                Toggle("Use Image Instead of Color", isOn: $model.useBackgroundImage)

                if model.useBackgroundImage {
                    Toggle("Replace Entire Folder", isOn: $model.imageReplacesFolder)
                        .help("Use the image as the entire icon instead of embedding it inside the folder shape")

                    if let img = model.backgroundImage {
                        VStack(spacing: 8) {
                            Image(nsImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            HStack {
                                Text("Scale")
                                Slider(value: $model.backgroundImageScale, in: 0.5...3.0, step: 0.1)
                                Text(String(format: "%.1f×", model.backgroundImageScale))
                                    .monospacedDigit()
                                    .frame(width: 36)
                            }

                            HStack {
                                Text("X")
                                Slider(value: $model.backgroundImageOffset.x, in: -200...200)
                                Text("Y")
                                Slider(value: $model.backgroundImageOffset.y, in: -200...200)
                            }

                            HStack {
                                Button("Choose Image...") {
                                    pickImage()
                                }
                                Button("Remove") {
                                    model.backgroundImage = nil
                                }
                            }
                        }
                    } else {
                        // Drop zone
                        VStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("Drop image here or click to browse")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 80)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                                .foregroundStyle(isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.4))
                        )
                        .onTapGesture { pickImage() }
                        .dropDestination(for: Data.self) { items, _ in
                            if let data = items.first, let img = NSImage(data: data) {
                                model.backgroundImage = img
                                return true
                            }
                            return false
                        } isTargeted: { targeted in
                            isDropTargeted = targeted
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func pickImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            model.backgroundImage = NSImage(contentsOf: url)
        }
    }
}
