import AppKit
import Foundation

/// A single saved icon in the collection
struct CollectionItem: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var groupID: UUID?
    var createdAt: Date
    /// Relative path to the saved PNG within the collection directory
    var imagePath: String

    init(id: UUID = UUID(), name: String, groupID: UUID? = nil, imagePath: String) {
        self.id = id
        self.name = name
        self.groupID = groupID
        self.createdAt = Date()
        self.imagePath = imagePath
    }
}

/// A user-created group for organizing collection items
struct CollectionGroup: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var createdAt: Date

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
        self.createdAt = Date()
    }
}
