import SwiftUI
import UniformTypeIdentifiers

/// A single icon cell in the collection grid — supports drag-out for export
struct CollectionItemCell: View {
    var store: CollectionStore
    var item: CollectionItem
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 4) {
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

            Text(item.name)
                .font(.caption2)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Color.secondary.opacity(0.1) : Color.clear)
        )
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
