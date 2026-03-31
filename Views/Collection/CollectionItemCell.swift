import SwiftUI
import UniformTypeIdentifiers

/// A single icon cell in the collection grid — supports drag-out for export
struct CollectionItemCell: View {
    var store: CollectionStore
    var item: CollectionItem
    var onTap: ((NSImage) -> Void)? = nil
    @State private var isHovering = false

    var body: some View {
        let cellContent = Group {
            if let img = store.image(for: item) {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 64, height: 64)
                    .overlay {
                        Image(systemName: "questionmark")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Color.secondary.opacity(0.1) : Color.clear)
        )

        Group {
            if let onTap {
                Button {
                    if let img = store.image(for: item) { onTap(img) }
                } label: {
                    cellContent
                }
                .buttonStyle(.plain)
            } else {
                cellContent
            }
        }
        .onHover { isHovering = $0 }
        .draggable(TransferableFileURL(url: store.fileURL(for: item)))
        .contextMenu {
            Button("Delete") {
                store.removeItem(item)
            }
        }
    }
}

/// Wrapper to make a file URL draggable for export
struct TransferableFileURL: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .png) { item in
            SentTransferredFile(item.url)
        }
    }
}
