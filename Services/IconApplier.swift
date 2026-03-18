import AppKit

struct IconApplier {
    static func applyIcon(_ image: NSImage, to folderURL: URL) -> Bool {
        NSWorkspace.shared.setIcon(image, forFile: folderURL.path, options: [])
    }

    static func removeIcon(from folderURL: URL) -> Bool {
        NSWorkspace.shared.setIcon(nil, forFile: folderURL.path, options: [])
    }
}
