import SwiftUI

struct DesignsTabView: View {
    @Bindable var model: FolderIconModel

    private let allPacks = MarketIconPack.loadBundled()
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)
    @State private var searchText = ""
    @State private var selectedTags: [String] = []
    @State private var isSearchFocused = false
    @FocusState private var textFieldFocused: Bool

    /// All unique tags across all packs
    private var allTags: [String] {
        var seen = Set<String>()
        var result = [String]()
        for pack in allPacks {
            for tag in pack.tags ?? [] {
                let lower = tag.lowercased()
                if !seen.contains(lower) {
                    seen.insert(lower)
                    result.append(tag)
                }
            }
        }
        return result
    }

    /// Tags matching current search text (for suggestions)
    private var suggestedTags: [String] {
        if searchText.isEmpty { return allTags }
        let query = searchText.lowercased()
        return allTags.filter {
            $0.lowercased().contains(query) && !selectedTags.contains($0.lowercased())
        }
    }

    private var filteredPacks: [MarketIconPack] {
        if selectedTags.isEmpty { return allPacks }
        return allPacks.filter { pack in
            guard let tags = pack.tags else { return false }
            let packTagsLower = tags.map { $0.lowercased() }
            return selectedTags.allSatisfy { packTagsLower.contains($0) }
        }
    }

    var body: some View {
        if allPacks.isEmpty {
            ContentUnavailableView("No Designs Yet",
                                   systemImage: "square.grid.2x2",
                                   description: Text("Pre-made folder icon designs will appear here."))
        } else {
            VStack(spacing: 0) {
                // Search box with selected tags
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 12))

                        // Selected tag pills
                        ForEach(selectedTags, id: \.self) { tag in
                            HStack(spacing: 2) {
                                Text(tag)
                                    .font(.caption)
                                Button {
                                    selectedTags.removeAll { $0 == tag }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8, weight: .bold))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.primary.opacity(0.1))
                            )
                        }

                        TextField("Search tags...", text: $searchText)
                            .textFieldStyle(.plain)
                            .focused($textFieldFocused)
                            .onSubmit {
                                addTagFromSearch()
                            }
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.08))
                    )

                    // Tag suggestions (shown when focused)
                    if textFieldFocused && !suggestedTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(suggestedTags, id: \.self) { tag in
                                    Button {
                                        addTag(tag)
                                    } label: {
                                        Text("#\(tag)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(Color.secondary.opacity(0.08))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(filteredPacks) { pack in
                            VStack(alignment: .leading, spacing: 8) {
                                if !pack.author.isEmpty {
                                    HStack(spacing: 4) {
                                        Text("by")
                                            .foregroundStyle(.secondary)
                                        if let link = pack.link, let url = URL(string: link) {
                                            AuthorLink(name: pack.author, url: url)
                                        } else {
                                            Text(pack.author)
                                        }
                                    }
                                    .font(.system(size: 15, weight: .medium))
                                }

                                // Tags
                                if let tags = pack.tags, !tags.isEmpty {
                                    HStack(spacing: 6) {
                                        ForEach(tags, id: \.self) { tag in
                                            Text("#\(tag)")
                                                .font(.caption)
                                                .foregroundStyle(tagColor(for: tag))
                                        }
                                    }
                                }

                                LazyVGrid(columns: columns, spacing: 8) {
                                    ForEach(pack.icons, id: \.self) { iconName in
                                        DesignIconCell(iconName: iconName) {
                                            applyIcon(named: iconName)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private func addTag(_ tag: String) {
        let lower = tag.lowercased()
        if !selectedTags.contains(lower) {
            selectedTags.append(lower)
        }
        searchText = ""
    }

    private func addTagFromSearch() {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return }
        // Match to an existing tag if possible
        if let match = allTags.first(where: { $0.lowercased().contains(trimmed) }) {
            addTag(match)
        } else {
            addTag(trimmed)
        }
    }

    private func tagColor(for tag: String) -> Color {
        if selectedTags.isEmpty {
            return .secondary
        }
        if selectedTags.contains(tag.lowercased()) {
            return .primary
        }
        return .secondary.opacity(0.5)
    }

    private func applyIcon(named iconName: String) {
        guard let url = Bundle.main.url(forResource: iconName,
                                         withExtension: nil),
              let image = NSImage(contentsOf: url) else { return }

        let folder = model.selectedFolderURL
        model.reset()
        model.selectedFolderURL = folder

        model.backgroundImage = image
        model.useBackgroundImage = true
        model.imageReplacesFolder = true
        model.backgroundImageOffset = .zero

        let canvasSize: CGFloat = 512
        let imgW = image.size.width
        let imgH = image.size.height
        if imgW > 0 && imgH > 0 {
            model.backgroundImageScale = min(canvasSize / imgW, canvasSize / imgH)
        }

        model.forceRender()
    }
}

struct DesignIconCell: View {
    let iconName: String
    let onTap: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                if let url = Bundle.main.url(forResource: iconName,
                                              withExtension: nil),
                   let image = NSImage(contentsOf: url) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(width: 72, height: 72)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovering ? Color.accentColor.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

struct AuthorLink: View {
    let name: String
    let url: URL
    @State private var isHovered = false

    var body: some View {
        Text(name)
            .foregroundStyle(isHovered ? Color.accentColor : .primary)
            .underline(isHovered)
            .onHover { hovering in
                isHovered = hovering
                if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
            .onTapGesture { NSWorkspace.shared.open(url) }
            .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}
