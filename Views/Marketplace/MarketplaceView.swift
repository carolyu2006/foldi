import SwiftUI

struct MarketplaceView: View {
    @State private var packs: [RemoteIconPack] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 72), spacing: 8)]

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading marketplace…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = errorMessage {
                ContentUnavailableView(
                    "Could not load marketplace",
                    systemImage: "wifi.exclamationmark",
                    description: Text(err)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if packs.isEmpty {
                ContentUnavailableView(
                    "No icon packs yet",
                    systemImage: "storefront",
                    description: Text("Check back soon for community icon packs.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(packs) { pack in
                            PackSection(pack: pack) { _ in }
                        }
                    }
                    .padding()
                }
            }
        }
        .task { await loadPacks() }
    }

    private func loadPacks() async {
        isLoading = true
        errorMessage = nil
        do {
            packs = try await SupabaseService.fetchIconPacks()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

}

// MARK: - Pack section

struct PackSection: View {
    let pack: RemoteIconPack
    let onSelect: (String) -> Void
    var showActions: Bool = true
    var iconsSelectable: Bool = true

    var isInitiallyInCollection: Bool = false

    @Environment(AppAuthService.self) private var auth
    @State private var isInWishlist: Bool = false
    @State private var isInCollection: Bool = false
    @State private var showSignIn: Bool = false

    private let columns = [GridItem(.adaptive(minimum: 72), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
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
                Spacer()
                if showActions {
                    HStack(spacing: 6) {
                        // Cart button — adds to wishlist_items; disabled when already in collection
                        Button {
                            guard auth.isSignedIn else { showSignIn = true; return }
                            let wasInWishlist = isInWishlist
                            SavedPacksStore.toggle(id: pack.id)
                            isInWishlist = SavedPacksStore.isSaved(pack.id)
                            NotificationCenter.default.post(name: .savedPacksChanged, object: nil)
                            if let userId = auth.userId, let token = auth.accessToken {
                                Task {
                                    if wasInWishlist {
                                        try? await SupabaseService.removeWishlistItem(userId: userId, packId: pack.id, accessToken: token)
                                    } else {
                                        try? await SupabaseService.addWishlistItem(userId: userId, packId: pack.id, accessToken: token)
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: isInWishlist ? "heart.fill" : "heart")
                                .foregroundStyle(isInWishlist ? Color(hex: "B11D1D") ?? .red : .primary)
                        }
                        .buttonStyle(ActionButtonStyle(isPrimary: false))
                        .disabled(isInCollection)
                        .opacity(isInCollection ? 0.35 : 1.0)

                        // Add button — adds to saved_packs; disabled when already in collection
                        Button {
                            guard auth.isSignedIn else { showSignIn = true; return }
                            if let userId = auth.userId, let token = auth.accessToken {
                                Task {
                                    try? await SupabaseService.addSavedPack(userId: userId, packId: pack.id, accessToken: token)
                                    await MainActor.run { isInCollection = true }
                                }
                            }
                        } label: {
                            if isInCollection {
                                Label("In Collection", systemImage: "checkmark")
                            } else {
                                Text("Add")
                            }
                        }
                        .buttonStyle(ActionButtonStyle(isPrimary: !isInCollection))
                        .disabled(isInCollection)
                        .opacity(isInCollection ? 0.4 : 1.0)
                    }
                }
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(pack.icons, id: \.self) { path in
                    RemoteIconCell(path: path, selectable: iconsSelectable) { onSelect(path) }
                }
            }
        }
        .onAppear {
            isInWishlist = SavedPacksStore.isSaved(pack.id)
            isInCollection = isInitiallyInCollection
        }
        .sheet(isPresented: $showSignIn) {
            SignInSheetView()
        }
    }
}

// MARK: - Async icon cell

struct RemoteIconCell: View {
    let path: String
    var selectable: Bool = true
    let onTap: () -> Void

    @State private var image: NSImage?
    @State private var isHovering = false

    var body: some View {
        let content = Group {
            if let img = image {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.1))
                    .overlay { ProgressView().scaleEffect(0.5) }
            }
        }
        .frame(width: 64, height: 64)
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(selectable && isHovering ? Color.secondary.opacity(0.1) : Color.clear)
        )

        if selectable {
            Button(action: onTap) { content }
                .buttonStyle(.plain)
                .onHover { isHovering = $0 }
                .task { image = try? await SupabaseService.fetchImage(path: path) }
        } else {
            content
                .task { image = try? await SupabaseService.fetchImage(path: path) }
        }
    }

    private var displayName: String {
        URL(fileURLWithPath: path)
            .deletingPathExtension()
            .lastPathComponent
            .replacingOccurrences(of: "_", with: " ")
    }
}
