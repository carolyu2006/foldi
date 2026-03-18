import SwiftUI

enum IconPosition: String, CaseIterable, Codable, Hashable {
    case topLeft, topCenter, topRight
    case middleLeft, center, middleRight
    case bottomLeft, bottomCenter, bottomRight
}

enum IconSize: String, CaseIterable, Codable, Hashable {
    case xs = "XS"
    case sm = "S"
    case md = "M"
    case lg = "L"
    case xl = "XL"
    case xxl = "XXL"

    /// Scale factor used for rendering (fraction of canvas)
    var scaleFactor: CGFloat {
        switch self {
        case .xs: 0.20
        case .sm: 0.30
        case .md: 0.40
        case .lg: 0.50
        case .xl: 0.60
        case .xxl: 0.70
        }
    }

    /// Display value shown to user (scaleFactor × 512, the "original" canvas-pixel value)
    var displayValue: CGFloat {
        scaleFactor * 512.0
    }
}

@Observable
final class FolderIconModel {
    var selectedFolderURL: URL?
    var currentFolderIcon: NSImage?
    /// When true, the folder's current Finder icon is used as the base instead of the colored template.
    var useCurrentFolderIcon: Bool = true

    // Style
    var folderTintColor: Color = Color(hex: "FFFFFF") ?? .white
    var folderBackColor: Color = Color(hex: "A72424") ?? .red

    // Background image
    var useBackgroundImage: Bool = false
    var backgroundImage: NSImage?
    var backgroundImageOffset: CGPoint = .zero
    var backgroundImageScale: CGFloat = 1.0
    /// When true, the background image replaces the entire folder icon instead of being embedded inside the folder shape.
    var imageReplacesFolder: Bool = false

    // Text overlay
    var textOverlay = TextOverlay()

    // Icon overlay
    var iconOverlay = IconOverlay()

    // Glass layout: 3 independent emojis with position & rotation
    var glassEmojis: [GlassEmoji] = [
        GlassEmoji(emoji: "🎵", position: .middleLeft, customOffset: CGPoint(x: 0.03, y: -0.01), rotation: 15, sizePreset: .lg),
        GlassEmoji(emoji: "📅", position: .center, customOffset: CGPoint(x: 0, y: -0.12), rotation: 6, sizePreset: .lg),
        GlassEmoji(emoji: "💻", position: .middleRight, customOffset: CGPoint(x: -0.03, y: -0.01), rotation: -16, sizePreset: .lg),
    ]
    var useGlassLayout: Bool = false

    // Prompt
    var promptText: String = ""

    // State
    var hasUnsavedChanges: Bool = false
    /// Bumped to force preview re-render when batch mutations occur
    var renderVersion: Int = 0

    // AI conversation state
    var aiResponseId: String?
    var aiCandidates: [NSImage] = []
    var selectedCandidateIndex: Int?
    var aiUndoStack: [(prompt: String, image: NSImage?, responseId: String?)] = []
    var isInFeedbackMode: Bool { aiResponseId != nil }

    /// Collection item IDs that are starred as reference images for AI generation
    var starredCollectionIDs: Set<UUID> = []
    /// Maps candidate index → collection item ID (when saved to collection)
    var aiCandidateCollectionIDs: [Int: UUID] = [:]
    static let maxReferenceImages = 6

    func forceRender() {
        renderVersion += 1
    }

    func applyBaseColor(_ base: Color) {
        let nsBase = NSColor(base).usingColorSpace(.sRGB) ?? NSColor(base)
        let lighter = nsBase.blended(withFraction: 0.35, of: .white) ?? nsBase
        let darker = nsBase.blended(withFraction: 0.25, of: .black) ?? nsBase
        folderTintColor = Color(lighter)
        folderBackColor = Color(darker)
        iconOverlay.color = Color(darker)
        textOverlay.color = Color(darker)
        useCurrentFolderIcon = false
        hasUnsavedChanges = true
    }

    func loadCurrentIcon() {
        guard let url = selectedFolderURL else {
            currentFolderIcon = nil
            return
        }
        currentFolderIcon = NSWorkspace.shared.icon(forFile: url.path)
        useCurrentFolderIcon = true
    }

    func pushAIUndo() {
        aiUndoStack.append((prompt: promptText, image: backgroundImage, responseId: aiResponseId))
    }

    func popAIUndo() {
        guard let previous = aiUndoStack.popLast() else { return }
        promptText = previous.prompt
        backgroundImage = previous.image
        aiResponseId = previous.responseId
        if let img = previous.image {
            useBackgroundImage = true
            // Update candidates selection if image is in candidates
            if let idx = aiCandidates.firstIndex(where: { $0 === img }) {
                selectedCandidateIndex = idx
            }
        }
        forceRender()
    }

    func clearAIConversation() {
        aiResponseId = nil
        aiCandidates = []
        selectedCandidateIndex = nil
        aiUndoStack = []
        aiCandidateCollectionIDs = [:]
    }

    func reset() {
        useBackgroundImage = false
        backgroundImage = nil
        backgroundImageOffset = .zero
        backgroundImageScale = 1.0
        imageReplacesFolder = false
        textOverlay = TextOverlay()
        iconOverlay = IconOverlay()
        glassEmojis = [
            GlassEmoji(emoji: "🎵", position: .middleLeft, customOffset: CGPoint(x: 0.03, y: -0.01), rotation: 15, sizePreset: .lg),
            GlassEmoji(emoji: "📅", position: .center, customOffset: CGPoint(x: 0, y: -0.12), rotation: 6, sizePreset: .lg),
            GlassEmoji(emoji: "💻", position: .middleRight, customOffset: CGPoint(x: -0.03, y: -0.01), rotation: -16, sizePreset: .lg),
        ]
        useGlassLayout = false
        promptText = ""
        clearAIConversation()
        // Restore to the folder's current Finder icon (same as when first dragged in)
        loadCurrentIcon()
        hasUnsavedChanges = false
        forceRender()
    }
}
