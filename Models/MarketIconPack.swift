import Foundation

struct MarketIconPack: Identifiable, Codable {
    var id: String { name }
    let name: String
    let author: String
    let link: String?
    let tags: [String]?
    let icons: [String]

    /// Load all packs from the bundled packs.json in Resources/MarketIcons
    static func loadBundled() -> [MarketIconPack] {
        guard let url = Bundle.main.url(forResource: "packs",
                                         withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let packs = try? JSONDecoder().decode([MarketIconPack].self, from: data) else {
            return []
        }
        return packs
    }
}
