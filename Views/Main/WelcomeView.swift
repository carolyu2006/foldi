import SwiftUI

struct ScatteredIcon: Identifiable {
    let id = UUID()
    let imageName: String
    let x: CGFloat      // fraction 0...1
    let y: CGFloat      // fraction 0...1
    let rotation: Double // degrees
    let scale: CGFloat
}

struct WelcomeView: View {
    @Bindable var model: FolderIconModel
    var bookmarkManager: BookmarkManager
    @State private var isDropTargeted = false
    @State private var isHovered = false

    private var active: Bool { isHovered || isDropTargeted }

    private let imageNames = ["emoji", "blank", "left", "glass", "right", "text"]

    @State private var scatteredIcons: [ScatteredIcon] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Radial gradient background
                RadialGradient(
                    colors: active
                        ? [Color.accentColor.opacity(0.12), Color.accentColor.opacity(0.03), Color.clear]
                        : [Color.secondary.opacity(0.06), Color.secondary.opacity(0.02), Color.clear],
                    center: .center,
                    startRadius: 20,
                    endRadius: 350
                )

                // Scattered background images
                ForEach(scatteredIcons) { icon in
                    if let url = Bundle.main.url(forResource: icon.imageName, withExtension: "png"),
                       let nsImage = NSImage(contentsOf: url) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(icon.rotation))
                            .opacity(active ? 0.55 : 0.25)
                            .position(
                                x: icon.x * geo.size.width,
                                y: icon.y * geo.size.height
                            )
                    }
                }

                // Center content
                VStack(spacing: 20) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 64, weight: .ultraLight))
                        .foregroundStyle(
                            active
                                ? AnyShapeStyle(.linearGradient(colors: [.accentColor, .accentColor.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                                : AnyShapeStyle(.secondary)
                        )

                    VStack(spacing: 6) {
                        Text("Drop or select a folder")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(active ? .primary : .secondary)

                        Text("to start customizing")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onAppear {
            generateScatteredIcons()
        }
        .onTapGesture {
            selectFolder()
        }
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .animation(.easeOut(duration: 0.2), value: active)
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir),
                  isDir.boolValue else { return false }
            model.selectedFolderURL = url
            model.loadCurrentIcon()
            bookmarkManager.saveBookmark(for: url)
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
    }

    private func generateScatteredIcons() {
        // Manually placed for balanced layout around the center
        scatteredIcons = [
            ScatteredIcon(imageName: "left",  x: 0.12, y: 0.22, rotation: -12, scale: 1),
            ScatteredIcon(imageName: "glass", x: 0.88, y: 0.18, rotation: 15,  scale: 1),
            ScatteredIcon(imageName: "emoji", x: 0.15, y: 0.78, rotation: -8,   scale: 1),
            ScatteredIcon(imageName: "text",  x: 0.85, y: 0.82, rotation: -10, scale: 1),
            ScatteredIcon(imageName: "right", x: 0.82, y: 0.50, rotation: 18,  scale: 1),
            ScatteredIcon(imageName: "blank", x: 0.18, y: 0.50, rotation: -20, scale: 1),
        ]
    }

    private func selectFolder() {
        SandboxAccessManager.selectFolder { url in
            if let url {
                model.selectedFolderURL = url
                model.loadCurrentIcon()
                bookmarkManager.saveBookmark(for: url)
            }
        }
    }
}
