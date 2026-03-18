import SwiftUI
import UniformTypeIdentifiers

struct IconPreviewView: View {
    @Bindable var model: FolderIconModel
    var bookmarkManager: BookmarkManager
    @State private var isDropTargeted = false
    @State private var renderedImage: NSImage?
    @State private var renderWorkItem: DispatchWorkItem?
    @State private var isHoveringFolder = false

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height, 300)
            VStack(spacing: 0) {
                if model.selectedFolderURL != nil {
                    previewContent(size: size)
                } else {
                    placeholderContent(size: size)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir),
                  isDir.boolValue else { return false }
            switchToFolder(url)
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
    }

    @ViewBuilder
    private func previewContent(size: CGFloat) -> some View {
        VStack(spacing: 10) {
            ZStack {
                if let img = renderedImage {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: size, height: size)
                        .shadow(radius: 4)
                } else {
                    ProgressView()
                        .frame(width: size, height: size)
                }
            }
            .frame(width: size, height: size)

            HStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Text(model.selectedFolderURL?.lastPathComponent ?? "")
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHoveringFolder ? Color.secondary.opacity(0.12) : Color.secondary.opacity(0.06))
            )
            .onHover { isHoveringFolder = $0 }
            .onTapGesture { selectAndSwapFolder() }
            .animation(.easeOut(duration: 0.12), value: isHoveringFolder)
            .padding(.bottom, 30)
        }
        .onAppear {
            scheduleRender()
        }
        .onChange(of: renderHash) { scheduleRender() }
    }

    @ViewBuilder
    private func placeholderContent(size: CGFloat) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)
            Text("Drop or click to select a folder")
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .frame(width: size, height: size)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                .foregroundStyle(isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.3))
        )
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isDropTargeted ? Color.accentColor.opacity(0.05) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectFolder()
        }
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    private func selectFolder() {
        SandboxAccessManager.selectFolder { url in
            if let url {
                model.selectedFolderURL = url
                model.loadCurrentIcon()
                bookmarkManager.saveBookmark(for: url)
                scheduleRender()
            }
        }
    }

    private func selectAndSwapFolder() {
        SandboxAccessManager.selectFolder { url in
            if let url {
                switchToFolder(url)
            }
        }
    }

    private func switchToFolder(_ url: URL) {
        model.reset()
        model.selectedFolderURL = url
        model.loadCurrentIcon()
        bookmarkManager.saveBookmark(for: url)
        scheduleRender()
    }

    private var renderHash: String {
        let iconOff = "\(model.iconOverlay.customOffset.x),\(model.iconOverlay.customOffset.y)"
        let textOff = "\(model.textOverlay.customOffset.x),\(model.textOverlay.customOffset.y)"

        let glassHash = model.glassEmojis.map { "\($0.emoji)\($0.position)\($0.customOffset.x),\($0.customOffset.y)\($0.rotation)\($0.sizePreset)" }.joined()

        let p: [String] = [
            "\(model.folderTintColor)", "\(model.folderBackColor)",
            model.iconOverlay.emoji, model.iconOverlay.sfSymbolName,
            model.iconOverlay.fontAwesomeName,
            "\(model.iconOverlay.type)", "\(model.iconOverlay.color)",
            "\(model.iconOverlay.position)", iconOff,
            "\(model.iconOverlay.sizePreset?.rawValue ?? "nil")",
            "\(model.iconOverlay.customSizeValue)",
            "\(model.iconOverlay.customImage?.size.width ?? 0)",
            "\(model.iconOverlay.shadowType)",
            "\(model.iconOverlay.shadowIntensity)",
            model.textOverlay.content, "\(model.textOverlay.color)",
            model.textOverlay.fontName, "\(model.textOverlay.fontWeight)",
            "\(model.textOverlay.shadowType)",
            "\(model.textOverlay.shadowIntensity)",
            "\(model.textOverlay.position)", textOff,
            "\(model.textOverlay.sizePreset?.rawValue ?? "nil")",
            "\(model.textOverlay.customFontSize)",
            "\(model.useCurrentFolderIcon)",
            "\(model.useBackgroundImage)", "\(model.imageReplacesFolder)",
            "\(model.backgroundImageScale)",
            "\(model.backgroundImageOffset.x),\(model.backgroundImageOffset.y)",
            "\(model.useGlassLayout)", glassHash,
            "\(model.renderVersion)",
        ]
        return p.joined(separator: "|")
    }

    private func scheduleRender() {
        renderWorkItem?.cancel()
        let item = DispatchWorkItem {
            let img = FolderIconRenderer.render(model: model)
            self.renderedImage = img
        }
        renderWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: item)
    }
}
