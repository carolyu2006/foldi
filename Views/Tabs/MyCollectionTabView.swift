import SwiftUI

struct MyCollectionTabView: View {
    @Bindable var model: FolderIconModel

    @Environment(AppAuthService.self) private var auth
    @State private var savedPacks: [RemoteIconPack] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSignIn = false
    @State private var searchText = ""
    @State private var localPacks: [MarketIconPack] = []
    @FocusState private var searchFocused: Bool

    private let columns = [GridItem(.adaptive(minimum: 72), spacing: 8)]

    private var filteredPacks: [RemoteIconPack] {
        guard !searchText.isEmpty else { return savedPacks }
        let q = searchText.lowercased()
        return savedPacks.filter {
            $0.name.lowercased().contains(q) ||
            $0.author.lowercased().contains(q) ||
            ($0.tags ?? []).contains { $0.lowercased().contains(q) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            if auth.isSignedIn && !savedPacks.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12))
                    TextField("Search collection…", text: $searchText)
                        .textFieldStyle(.plain)
                        .focused($searchFocused)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.08))
                )
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }

            Group {
                if isLoading {
                    ProgressView("Loading collection…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = errorMessage {
                    ContentUnavailableView(
                        "Could not load collection",
                        systemImage: "wifi.exclamationmark",
                        description: Text(err)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 24) {
                            if !auth.isSignedIn {
                                loginPrompt
                                if !localPacks.isEmpty {
                                    VStack(alignment: .leading, spacing: 16) {
                                        Text("Free Packs")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(.secondary)
                                        ForEach(localPacks) { pack in
                                            BundledPackSection(pack: pack) { filename in
                                                applyLocalIcon(filename: filename)
                                            }
                                        }
                                    }
                                }
                            } else if savedPacks.isEmpty {
                                ContentUnavailableView(
                                    "No packs yet",
                                    systemImage: "square.grid.2x2",
                                    description: Text("Your icon packs will appear here.")
                                )
                                .frame(maxWidth: .infinity)
                                .padding(.top, 60)
                            } else if filteredPacks.isEmpty {
                                ContentUnavailableView(
                                    "No results",
                                    systemImage: "magnifyingglass",
                                    description: Text("No packs match \"\(searchText)\".")
                                )
                                .frame(maxWidth: .infinity)
                                .padding(.top, 60)
                            } else {
                                ForEach(filteredPacks) { pack in
                                    PackSection(pack: pack, onSelect: { path in
                                        applyRemoteIcon(path: path)
                                    }, showActions: false)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .task {
            localPacks = MarketIconPack.loadBundled()
            await loadSavedPacks()
        }
        .onChange(of: auth.isSignedIn) { _, _ in
            Task { await loadSavedPacks() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .savedPacksChanged)) { _ in
            Task { await loadSavedPacks() }
        }
        .sheet(isPresented: $showSignIn) {
            SignInSheetView()
        }
    }

    // MARK: - Data loading

    private func loadSavedPacks() async {
        guard auth.isSignedIn else { savedPacks = []; return }
        isLoading = true
        errorMessage = nil
        do {
            try await fetchPacks()
        } catch SupabaseError.httpError(401, _) {
            // Token expired — refresh and retry once
            await auth.refreshIfNeeded()
            if auth.isSignedIn {
                do { try await fetchPacks() } catch { errorMessage = error.localizedDescription }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func fetchPacks() async throws {
        guard let userId = auth.userId, let accessToken = auth.accessToken else { return }
        let ids = try await SupabaseService.fetchSavedPackIds(userId: userId, accessToken: accessToken)
        savedPacks = try await SupabaseService.fetchPacksByIds(ids, accessToken: accessToken)
    }

    // MARK: - Apply icons

    private func applyLocalIcon(filename: String) {
        let name = (filename as NSString).deletingPathExtension
        let ext  = (filename as NSString).pathExtension
        guard let url = Bundle.main.url(forResource: name, withExtension: ext),
              let image = NSImage(contentsOf: url) else { return }
        applyImage(image)
    }

    private func applyRemoteIcon(path: String) {
        Task {
            guard let image = try? await SupabaseService.fetchImage(path: path) else { return }
            await MainActor.run { applyImage(image) }
        }
    }

    private func applyImage(_ image: NSImage) {
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

    // MARK: - Subviews

    private var loginPrompt: some View {
        VStack(spacing: 14) {
            Image(systemName: "bookmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.primary)

            VStack(spacing: 4) {
                Text("Login to see your collection")
                    .font(.system(size: 15, weight: .semibold))
                Text("Sign in to access your saved packs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 10) {
                Button("Sign In") { showSignIn = true }
                    .buttonStyle(ActionButtonStyle(isPrimary: true))

                Button("Sign Up") {
                    NSWorkspace.shared.open(URL(string: "https://foldi.org/auth?tab=signup")!)
                }
                .buttonStyle(ActionButtonStyle(isPrimary: false))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.primary.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
        )
    }

}

// MARK: - Bundled pack section

struct BundledPackSection: View {
    let pack: MarketIconPack
    let onSelect: (String) -> Void

    private let columns = [GridItem(.adaptive(minimum: 72), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(pack.name).font(.headline)
                Text("by \(pack.author)").font(.caption).foregroundStyle(.secondary)
                if let tags = pack.tags, !tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(tags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.secondary.opacity(0.08))
                                    )
                            }
                        }
                    }
                }
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(pack.icons, id: \.self) { filename in
                    BundledIconCell(filename: filename) { onSelect(filename) }
                }
            }
        }
    }
}

struct BundledIconCell: View {
    let filename: String
    let onTap: () -> Void

    @State private var image: NSImage?
    @State private var isHovering = false

    var body: some View {
        Button(action: onTap) {
            Group {
                if let img = image {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.1))
                }
            }
            .frame(width: 64, height: 64)
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovering ? Color.secondary.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .onAppear {
            let name = (filename as NSString).deletingPathExtension
            let ext  = (filename as NSString).pathExtension
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                image = NSImage(contentsOf: url)
            }
        }
    }
}
