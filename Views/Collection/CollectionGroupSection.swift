import SwiftUI
import UniformTypeIdentifiers

/// A section showing a group's items in a grid, with drag-and-drop support
struct CollectionGroupSection: View {
    var store: CollectionStore
    var group: CollectionGroup?
    var title: String?
    @State private var isDropTargeted = false
    @State private var editingName = false
    @State private var editName = ""

    private var sectionTitle: String {
        title ?? group?.name ?? "Ungrouped"
    }

    private var sectionItems: [CollectionItem] {
        store.items(in: group?.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader
            itemsGrid
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isDropTargeted ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isDropTargeted ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .dropDestination(for: URL.self) { urls, _ in
            for url in urls {
                store.addExternalImage(url: url, groupID: group?.id)
            }
            return !urls.isEmpty
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
    }

    @ViewBuilder
    private var sectionHeader: some View {
        HStack {
            if editingName {
                TextField("Group name", text: $editName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
                    .onSubmit {
                        if let g = group, !editName.isEmpty {
                            store.renameGroup(g, to: editName)
                        }
                        editingName = false
                    }
            } else {
                Text(sectionTitle)
                    .font(.headline)
                    .onTapGesture(count: 2) {
                        if group != nil {
                            editName = sectionTitle
                            editingName = true
                        }
                    }
            }

            Spacer()

            if let g = group {
                Button {
                    store.removeGroup(g)
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Delete group (items move to Ungrouped)")
            }
        }
    }

    @ViewBuilder
    private var itemsGrid: some View {
        if sectionItems.isEmpty {
            Text("Drop images here")
                .font(.caption)
                .foregroundStyle(.quaternary)
                .frame(maxWidth: .infinity, minHeight: 60)
        } else {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(80), spacing: 8), count: 4), spacing: 8) {
                ForEach(sectionItems) { item in
                    CollectionItemCell(store: store, item: item)
                }
            }
        }
    }
}
