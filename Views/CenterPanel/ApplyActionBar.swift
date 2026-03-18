import SwiftUI

struct ApplyActionBar: View {
    @Bindable var model: FolderIconModel
    var collectionStore: CollectionStore
    var bookmarkManager: BookmarkManager

    var body: some View {
        HStack(spacing: 20) {
            Button("Reset") {
                model.reset()
            }
            .buttonStyle(ActionButtonStyle(isPrimary: false))

            Button("Apply") {
                guard let url = model.selectedFolderURL else { return }
                let icon = FolderIconRenderer.render(model: model)

                bookmarkManager.accessBookmarkedURL(url) { resolvedURL in
                    IconBackupService.backup(folderURL: resolvedURL)
                    _ = IconApplier.applyIcon(icon, to: resolvedURL)
                }

                let name = url.lastPathComponent
                collectionStore.addItem(name: name, image: icon)
            }
            .buttonStyle(ActionButtonStyle(isPrimary: true))
            .disabled(model.selectedFolderURL == nil)
        }
        .fixedSize()
        .frame(maxWidth: .infinity)
    }
}

struct ActionButtonStyle: ButtonStyle {
    let isPrimary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(isPrimary ? .white : .primary)
            .padding(.horizontal, 20)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isPrimary ? (Color(hex: "212121") ?? .primary) : Color.secondary.opacity(0.15))
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}
