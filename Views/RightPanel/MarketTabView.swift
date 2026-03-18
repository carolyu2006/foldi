import SwiftUI

struct MarketTabView: View {
    @Bindable var model: FolderIconModel

    private let packs = MarketIconPack.loadBundled()

    private let columns = [
        GridItem(.adaptive(minimum: 72), spacing: 8)
    ]

    var body: some View {
        if packs.isEmpty {
            ContentUnavailableView("No Packs",
                                   systemImage: "storefront",
                                   description: Text("Add icon packs to Resources/MarketIcons."))
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(packs) { pack in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(pack.name)
                                .font(.headline)
                            Text("by \(pack.author)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            LazyVGrid(columns: columns, spacing: 8) {
                                ForEach(pack.icons, id: \.self) { iconName in
                                    MarketIconCell(iconName: iconName) {
                                        applyIcon(named: iconName)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func applyIcon(named iconName: String) {
        guard let url = Bundle.main.url(forResource: iconName,
                                         withExtension: nil,
),
              let image = NSImage(contentsOf: url) else { return }
        model.backgroundImage = image
        model.useBackgroundImage = true
        model.forceRender()
    }
}

struct MarketIconCell: View {
    let iconName: String
    let onTap: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                if let url = Bundle.main.url(forResource: iconName,
                                              withExtension: nil,
     ),
                   let image = NSImage(contentsOf: url) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(width: 64, height: 64)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                }

                Text(iconName.replacingOccurrences(of: ".png", with: "")
                        .replacingOccurrences(of: "_", with: " "))
                    .font(.caption2)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovering ? Color.secondary.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
