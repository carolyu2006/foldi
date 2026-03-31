import AppKit
import Foundation

/// Manages persistent storage of the icon collection (groups + items + images)
@Observable
final class CollectionStore {
    private(set) var items: [CollectionItem] = []
    private(set) var groups: [CollectionGroup] = []

    private let baseDir: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        baseDir = appSupport.appendingPathComponent("FolderIcon/Collection", isDirectory: true)
        try? FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)
        load()
    }

    // MARK: - Directory

    private var imagesDir: URL {
        let url = baseDir.appendingPathComponent("Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private var metadataURL: URL {
        baseDir.appendingPathComponent("collection.json")
    }

    // MARK: - Save / Load metadata

    private struct Metadata: Codable {
        var items: [CollectionItem]
        var groups: [CollectionGroup]
    }

    private func save() {
        let meta = Metadata(items: items, groups: groups)
        if let data = try? JSONEncoder().encode(meta) {
            try? data.write(to: metadataURL, options: .atomic)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: metadataURL),
              let meta = try? JSONDecoder().decode(Metadata.self, from: data) else { return }
        items = meta.items
        groups = meta.groups
    }

    // MARK: - Items

    /// Save a rendered icon to the collection
    func addItem(name: String, image: NSImage, groupID: UUID? = nil) -> CollectionItem {
        let id = UUID()
        let filename = "\(id.uuidString).png"
        let fileURL = imagesDir.appendingPathComponent(filename)

        // Write PNG
        if let tiff = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff),
           let png = bitmap.representation(using: .png, properties: [:]) {
            try? png.write(to: fileURL, options: .atomic)
        }

        let item = CollectionItem(id: id, name: name, groupID: groupID, imagePath: filename)
        items.append(item)

        // Keep only the most recent 30 items
        let maxItems = 20
        if items.count > maxItems {
            let toRemove = items.prefix(items.count - maxItems)
            for old in toRemove {
                let oldURL = imagesDir.appendingPathComponent(old.imagePath)
                try? FileManager.default.removeItem(at: oldURL)
            }
            items.removeFirst(items.count - maxItems)
        }

        save()
        return item
    }

    /// Add an external image file (drag-in) to the collection
    func addExternalImage(url: URL, groupID: UUID? = nil) -> CollectionItem? {
        guard let image = NSImage(contentsOf: url) else { return nil }
        let name = url.deletingPathExtension().lastPathComponent
        return addItem(name: name, image: image, groupID: groupID)
    }

    func removeItem(_ item: CollectionItem) {
        items.removeAll { $0.id == item.id }
        let fileURL = imagesDir.appendingPathComponent(item.imagePath)
        try? FileManager.default.removeItem(at: fileURL)
        save()
    }

    func moveItem(_ item: CollectionItem, toGroup groupID: UUID?) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].groupID = groupID
        save()
    }

    func renameItem(_ item: CollectionItem, to name: String) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].name = name
        save()
    }

    /// Load the NSImage for a collection item
    func image(for item: CollectionItem) -> NSImage? {
        let url = imagesDir.appendingPathComponent(item.imagePath)
        return NSImage(contentsOf: url)
    }

    /// Full file URL for drag-out export
    func fileURL(for item: CollectionItem) -> URL {
        imagesDir.appendingPathComponent(item.imagePath)
    }

    func items(in groupID: UUID?) -> [CollectionItem] {
        items.filter { $0.groupID == groupID }
    }

    // MARK: - Groups

    @discardableResult
    func addGroup(name: String) -> CollectionGroup {
        let group = CollectionGroup(name: name)
        groups.append(group)
        save()
        return group
    }

    func removeGroup(_ group: CollectionGroup) {
        // Move items in this group to ungrouped
        for i in items.indices where items[i].groupID == group.id {
            items[i].groupID = nil
        }
        groups.removeAll { $0.id == group.id }
        save()
    }

    func renameGroup(_ group: CollectionGroup, to name: String) {
        guard let idx = groups.firstIndex(where: { $0.id == group.id }) else { return }
        groups[idx].name = name
        save()
    }

    // MARK: - Marketplace (placeholder)

    /// Download a collection pack from the marketplace
    func downloadFromMarketplace(packID: String) async throws {
        // TODO: Implement marketplace download
        // Will download a pack of icons and import them into the collection
        fatalError("Marketplace download not yet implemented")
    }

    /// Upload/share a collection to the marketplace
    func uploadToMarketplace(groupID: UUID) async throws {
        // TODO: Implement marketplace upload
        // Will package a group of icons and upload to the marketplace
        fatalError("Marketplace upload not yet implemented")
    }

    /// Fetch available marketplace packs
    func fetchMarketplaceCatalog() async throws -> [MarketplacePack] {
        // TODO: Fetch from remote API
        return []
    }
}

/// Placeholder model for a marketplace pack
struct MarketplacePack: Identifiable, Codable {
    let id: String
    var name: String
    var description: String
    var author: String
    var iconCount: Int
    var previewImageURL: URL?
}
