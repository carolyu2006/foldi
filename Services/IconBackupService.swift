import AppKit

struct IconBackupService {
    private static let backupDir: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("FolderIcon/Backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static func backup(folderURL: URL) {
        guard let icon = NSWorkspace.shared.icon(forFile: folderURL.path) as NSImage? else { return }
        let data = icon.tiffRepresentation
        let file = backupDir.appendingPathComponent("\(folderURL.lastPathComponent)_\(Date().timeIntervalSince1970).tiff")
        try? data?.write(to: file)
    }

    static func restoreLatest(for folderURL: URL) -> Bool {
        let prefix = folderURL.lastPathComponent + "_"
        guard let files = try? FileManager.default.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: nil),
              let latest = files.filter({ $0.lastPathComponent.hasPrefix(prefix) }).sorted(by: { $0.path > $1.path }).first,
              let data = try? Data(contentsOf: latest),
              let image = NSImage(data: data) else {
            return false
        }
        return IconApplier.applyIcon(image, to: folderURL)
    }

    static func pruneBackups(maxCount: Int = 20) {
        guard let files = try? FileManager.default.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: [.creationDateKey])
            .sorted(by: { ($0.path) > ($1.path) }) else { return }
        if files.count > maxCount {
            for file in files.dropFirst(maxCount) {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}
