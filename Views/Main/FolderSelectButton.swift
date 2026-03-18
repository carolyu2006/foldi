import SwiftUI

struct FolderSelectButton: View {
    @Bindable var model: FolderIconModel
    var bookmarkManager: BookmarkManager

    var body: some View {
        HStack {
            Spacer()
            Button {
                SandboxAccessManager.selectFolder { url in
                    if let url {
                        model.selectedFolderURL = url
                        model.loadCurrentIcon()
                        bookmarkManager.saveBookmark(for: url)
                    }
                }
            } label: {
                Text(model.selectedFolderURL?.lastPathComponent ?? "Select Folder")
                    .font(.title3)
            }
            .controlSize(.large)
            Spacer()
        }
    }
}
