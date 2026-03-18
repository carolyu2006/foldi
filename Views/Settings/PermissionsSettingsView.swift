import SwiftUI

struct PermissionsSettingsView: View {
    var bookmarkManager: BookmarkManager

    var body: some View {
        Form {
            Section("Bookmarked Folders") {
                if bookmarkManager.bookmarkedURLs.isEmpty {
                    Text("No folders bookmarked yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(bookmarkManager.bookmarkedURLs, id: \.self) { url in
                        HStack {
                            Image(systemName: "folder")
                            Text(url.path)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button(role: .destructive) {
                                bookmarkManager.removeBookmark(for: url)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
