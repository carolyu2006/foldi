import Foundation

@Observable
final class BookmarkManager {
    private let bookmarkKey = "savedBookmarks"
    private(set) var bookmarkedURLs: [URL] = []

    init() {
        loadBookmarks()
    }

    func saveBookmark(for url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try url.bookmarkData(options: .withSecurityScope,
                                            includingResourceValuesForKeys: nil,
                                            relativeTo: nil)
            var bookmarks = loadBookmarkData()
            bookmarks[url.path] = data
            UserDefaults.standard.set(bookmarks, forKey: bookmarkKey)
            loadBookmarks()
        } catch {
            print("Failed to save bookmark: \(error)")
        }
    }

    func removeBookmark(for url: URL) {
        var bookmarks = loadBookmarkData()
        bookmarks.removeValue(forKey: url.path)
        UserDefaults.standard.set(bookmarks, forKey: bookmarkKey)
        loadBookmarks()
    }

    func accessBookmarkedURL(_ url: URL, handler: (URL) -> Void) {
        let bookmarks = loadBookmarkData()
        if let data = bookmarks[url.path] {
            var isStale = false
            do {
                let resolved = try URL(resolvingBookmarkData: data,
                                       options: .withSecurityScope,
                                       relativeTo: nil,
                                       bookmarkDataIsStale: &isStale)
                if isStale {
                    // Re-save the bookmark so it doesn't stay stale
                    saveBookmark(for: resolved)
                }
                guard resolved.startAccessingSecurityScopedResource() else {
                    print("Failed to start accessing security-scoped resource")
                    return
                }
                defer { resolved.stopAccessingSecurityScopedResource() }
                handler(resolved)
                return
            } catch {
                print("Failed to resolve bookmark: \(error)")
            }
        }
        // Fallback: try accessing the URL directly (works if still in sandbox scope from file dialog)
        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }
            handler(url)
        } else {
            // Last resort: just try it — NSWorkspace.setIcon may still work for some paths
            handler(url)
        }
    }

    private func loadBookmarks() {
        bookmarkedURLs = loadBookmarkData().keys.compactMap { URL(fileURLWithPath: $0) }
    }

    private func loadBookmarkData() -> [String: Data] {
        UserDefaults.standard.dictionary(forKey: bookmarkKey) as? [String: Data] ?? [:]
    }
}
