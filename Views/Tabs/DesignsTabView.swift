import SwiftUI

struct GalleryTabView: View {
    @Bindable var model: FolderIconModel

    @Environment(AppAuthService.self) private var auth

    @State private var searchText = ""
    @State private var selectedTags: [String] = []
    @FocusState private var textFieldFocused: Bool

    @State private var remotePacks: [RemoteIconPack] = []
    @State private var isLoadingRemote = true
    @State private var remoteError: String?
    @State private var savedPackIds: Set<String> = []

    private var allTags: [String] {
        var seen = Set<String>()
        var result = [String]()
        for pack in remotePacks {
            for tag in pack.tags ?? [] {
                let lower = tag.lowercased()
                if !seen.contains(lower) { seen.insert(lower); result.append(tag) }
            }
        }
        return result
    }

    private var suggestedTags: [String] {
        if searchText.isEmpty { return allTags }
        let query = searchText.lowercased()
        return allTags.filter {
            $0.lowercased().contains(query) && !selectedTags.contains($0.lowercased())
        }
    }

    private var filteredPacks: [RemoteIconPack] {
        if selectedTags.isEmpty { return remotePacks }
        return remotePacks.filter { pack in
            guard let tags = pack.tags else { return false }
            let packTagsLower = tags.map { $0.lowercased() }
            return selectedTags.allSatisfy { packTagsLower.contains($0) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search box with selected tag pills
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12))

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
                        .onSubmit { addTagFromSearch() }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.08))
                )

                if textFieldFocused && !suggestedTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(suggestedTags, id: \.self) { tag in
                                Button { addTag(tag) } label: {
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
                    if isLoadingRemote {
                        ProgressView("Loading gallery…")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    } else if let err = remoteError {
                        Label(err, systemImage: "wifi.exclamationmark")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(filteredPacks) { pack in
                            PackSection(
                                pack: pack,
                                onSelect: { _ in },
                                iconsSelectable: false,
                                isInitiallyInCollection: savedPackIds.contains(pack.id)
                            )
                        }
                    }
                }
                .padding()
            }
        }
        .task {
            await loadRemotePacks()
            await loadSavedPackIds()
        }
    }

    // MARK: - Helpers

    private func addTag(_ tag: String) {
        let lower = tag.lowercased()
        if !selectedTags.contains(lower) { selectedTags.append(lower) }
        searchText = ""
    }

    private func addTagFromSearch() {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return }
        if let match = allTags.first(where: { $0.lowercased().contains(trimmed) }) {
            addTag(match)
        } else {
            addTag(trimmed)
        }
    }

    private func tagColor(for tag: String) -> Color {
        if selectedTags.isEmpty { return .secondary }
        return selectedTags.contains(tag.lowercased()) ? .primary : .secondary.opacity(0.5)
    }

    private func applyRemoteIcon(path: String) {
        Task {
            guard let image = try? await SupabaseService.fetchImage(path: path) else { return }
            await MainActor.run {
                let folder = model.selectedFolderURL
                model.reset()
                model.selectedFolderURL = folder
                model.backgroundImage = image
                model.useBackgroundImage = true
                model.imageReplacesFolder = true
                model.backgroundImageOffset = .zero
                let canvas: CGFloat = 512
                if image.size.width > 0 && image.size.height > 0 {
                    model.backgroundImageScale = min(canvas / image.size.width, canvas / image.size.height)
                }
                model.forceRender()
            }
        }
    }

    private func loadSavedPackIds() async {
        guard let userId = auth.userId, let token = auth.accessToken else { return }
        let ids = (try? await SupabaseService.fetchSavedPackIds(userId: userId, accessToken: token)) ?? []
        savedPackIds = Set(ids)
    }

    private func loadRemotePacks() async {
        isLoadingRemote = true
        remoteError = nil
        do {
            remotePacks = try await SupabaseService.fetchIconPacks()
        } catch {
            remoteError = error.localizedDescription
        }
        isLoadingRemote = false
    }
}
