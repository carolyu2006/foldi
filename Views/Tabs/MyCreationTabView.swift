import SwiftUI

struct MyCreationTabView: View {
    @Bindable var model: FolderIconModel
    var collectionStore: CollectionStore

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        if collectionStore.items.isEmpty {
            ContentUnavailableView("No Creations Yet",
                                   systemImage: "square.grid.2x2",
                                   description: Text("Icons will appear here when you apply them to a folder."))
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(collectionStore.items.reversed()) { item in
                        CreationCell(store: collectionStore, item: item) {
                            applyItem(item)
                        }
                    }
                }
                .padding()
            }
        }
    }

    private func applyItem(_ item: CollectionItem) {
        guard let image = collectionStore.image(for: item) else { return }

        let folder = model.selectedFolderURL
        model.reset()
        model.selectedFolderURL = folder

        model.backgroundImage = image
        model.useBackgroundImage = true
        model.imageReplacesFolder = true
        model.backgroundImageOffset = .zero

        let canvasSize: CGFloat = 512
        let imgW = image.size.width
        let imgH = image.size.height
        if imgW > 0 && imgH > 0 {
            model.backgroundImageScale = max(canvasSize / imgW, canvasSize / imgH)
        }

        model.forceRender()
    }
}

struct CreationCell: View {
    var store: CollectionStore
    var item: CollectionItem
    let onTap: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                if let img = store.image(for: item) {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(width: 72, height: 72)
                        .overlay {
                            Image(systemName: "questionmark")
                                .foregroundStyle(.secondary)
                        }
                }

}
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovering ? Color.accentColor.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Delete") {
                store.removeItem(item)
            }
        }
    }
}
