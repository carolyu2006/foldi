import SwiftUI

/// Sheet that lets users pick a saved icon from the collection to load as background image
struct LoadFromCollectionSheet: View {
    var store: CollectionStore
    @Bindable var model: FolderIconModel
    @Binding var isPresented: Bool
    @State private var selectedItem: CollectionItem?

    var body: some View {
        VStack(spacing: 16) {
            Text("Load from Collection")
                .font(.headline)

            if store.items.isEmpty {
                VStack(spacing: 8) {
                    Text("No saved icons")
                        .foregroundStyle(.secondary)
                    Text("Apply an icon to a folder to save it to your collection.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(height: 200)
            } else {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(80), spacing: 8), count: 4), spacing: 8) {
                        ForEach(store.items) { item in
                            VStack(spacing: 4) {
                                if let img = store.image(for: item) {
                                    Image(nsImage: img)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 64, height: 64)
                                } else {
                                    Color.secondary.opacity(0.1)
                                        .frame(width: 64, height: 64)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                Text(item.name)
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                            .padding(4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedItem?.id == item.id ? Color.accentColor.opacity(0.2) : Color.clear)
                            )
                            .onTapGesture { selectedItem = item }
                        }
                    }
                }
                .frame(height: 260)
            }

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Load") {
                    if let item = selectedItem, let img = store.image(for: item) {
                        model.useBackgroundImage = true
                        model.backgroundImage = img
                    }
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedItem == nil)
            }
        }
        .padding(24)
        .frame(width: 400)
    }
}
