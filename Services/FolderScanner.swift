import Foundation

struct FolderScanResult {
    let tree: String
    let recentFileContents: [(name: String, content: String)]

    var fullContext: String {
        var parts = ["## Folder Structure", tree]
        if !recentFileContents.isEmpty {
            parts.append("\n## Recent File Contents")
            for file in recentFileContents {
                parts.append("### \(file.name)")
                parts.append("```\n\(file.content)\n```")
            }
        }
        return parts.joined(separator: "\n")
    }
}

struct FolderScanner {
    private static let textExtensions: Set<String> = [
        "swift", "md", "json", "py", "js", "ts", "tsx", "jsx",
        "html", "css", "txt", "yaml", "yml", "toml", "sh", "xml",
        "rs", "go", "java", "kt", "rb", "php", "c", "cpp", "h",
        "hpp", "m", "mm", "r", "sql", "graphql", "proto", "csv",
        "env", "ini", "cfg", "conf", "log", "makefile", "dockerfile",
        "gitignore", "editorconfig", "prettierrc", "eslintrc",
    ]

    static func scan(folderURL: URL) async -> FolderScanResult {
        let fm = FileManager.default
        let tree = buildTree(at: folderURL, fm: fm, depth: 0, maxDepth: 2)
        let recentFiles = findRecentTextFiles(at: folderURL, fm: fm, limit: 10)

        var contents: [(String, String)] = []
        for fileURL in recentFiles {
            if let text = readHead(of: fileURL, lineCount: 25) {
                let relativePath = fileURL.path.replacingOccurrences(
                    of: folderURL.path + "/", with: "")
                contents.append((relativePath, text))
            }
        }

        return FolderScanResult(tree: tree, recentFileContents: contents)
    }

    private static func buildTree(at url: URL, fm: FileManager, depth: Int, maxDepth: Int) -> String {
        guard depth <= maxDepth else { return "" }
        let indent = String(repeating: "  ", count: depth)
        var lines: [String] = []

        guard let items = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return "" }

        let sorted = items.sorted { $0.lastPathComponent < $1.lastPathComponent }
        for item in sorted {
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let name = item.lastPathComponent
            if isDir {
                lines.append("\(indent)\(name)/")
                lines.append(buildTree(at: item, fm: fm, depth: depth + 1, maxDepth: maxDepth))
            } else {
                lines.append("\(indent)\(name)")
            }
        }
        return lines.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    private static func findRecentTextFiles(at url: URL, fm: FileManager, limit: Int) -> [URL] {
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var textFiles: [(url: URL, date: Date)] = []
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey]),
                  values.isRegularFile == true,
                  let modDate = values.contentModificationDate else { continue }

            let ext = fileURL.pathExtension.lowercased()
            // Also include files with no extension (Makefile, Dockerfile, etc.)
            if textExtensions.contains(ext) || ext.isEmpty {
                textFiles.append((fileURL, modDate))
            }
        }

        return textFiles
            .sorted { $0.date > $1.date }
            .prefix(limit)
            .map(\.url)
    }

    private static func readHead(of url: URL, lineCount: Int) -> String? {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe),
              data.count < 1_000_000,
              let text = String(data: data, encoding: .utf8) else { return nil }

        let lines = text.components(separatedBy: .newlines).prefix(lineCount)
        return lines.joined(separator: "\n")
    }
}
