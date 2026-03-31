import SwiftUI

struct MyCreationTabView: View {
    @Bindable var model: FolderIconModel
    var collectionStore: CollectionStore

    @Environment(AppAuthService.self) private var auth

    @State private var myPacks: [RemoteIconPack] = []
    @State private var isLoadingMyPacks = false
    @State private var myPacksError: String?
@State private var showSignIn = false
    @State private var showAllHistory = false
    @State private var showUploadSheet = false

    private let expandedColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    // Newest first
    private var sortedItems: [CollectionItem] {
        collectionStore.items.reversed()
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {

                // ── Account ───────────────────────────────────────────────
                accountSection

                PageDivider()

                // ── History ───────────────────────────────────────────────
                HStack(alignment: .center) {
                    PageSectionHeader(title: "History")
                        .padding(.bottom, 0)
                    Spacer()
                    if !sortedItems.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showAllHistory.toggle()
                            }
                        } label: {
                            Image(systemName: showAllHistory ? "minus.circle" : "plus.circle")
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing)
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 8)

                if sortedItems.isEmpty {
                    PageEmptyState(icon: "clock", message: "Applied icons will appear here")
                } else if showAllHistory {
                    // Expanded: full grid
                    LazyVGrid(columns: expandedColumns, spacing: 8) {
                        ForEach(sortedItems) { item in
                            CollectionItemCell(store: collectionStore, item: item) { img in
                                applyHistoryImage(img)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                } else {
                    // Compact: horizontal scroll of newest 8
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(sortedItems.prefix(8)) { item in
                                CollectionItemCell(store: collectionStore, item: item) { img in
                                    applyHistoryImage(img)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 20)
                }

                PageDivider()

                // ── My Designs ────────────────────────────────────────────
                HStack(alignment: .center) {
                    PageSectionHeader(title: "My Designs")
                        .padding(.bottom, 0)
                    Spacer()
                    Button {
                        showUploadSheet = true
                    } label: {
                        Label("Publish Design", systemImage: "arrow.up.to.line.circle")
                    }
                    .buttonStyle(ActionButtonStyle(isPrimary: true))
                    .padding(.trailing)
                    .sheet(isPresented: $showUploadSheet) {
                        UploadPackSheet()
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 8)

                myDesignsSection

            }
        }
        .task(id: auth.username) {
            await loadMyPacks()
        }
    }

    // MARK: - Account section

    @ViewBuilder
    private var accountSection: some View {
        if auth.isSignedIn, let session = auth.session {
            HStack(spacing: 14) {
                // Avatar initial
                ZStack {
                    Circle()
                        .fill(Color(hex: "212121") ?? .primary)
                        .frame(width: 44, height: 44)
                    Text(String(session.displayName?.prefix(1) ?? session.username.prefix(1)).uppercased())
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.displayName ?? session.username)
                        .font(.system(size: 14, weight: .semibold))
                    Text("@\(session.username)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(session.email)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Button("Sign Out") {
                    Task { await auth.signOut() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundStyle(.red)
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 12)
        } else {
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 28))
                    .foregroundStyle(.tertiary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Not signed in")
                        .font(.system(size: 13, weight: .medium))
                    Text("Sign in to sync your designs and saved packs.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Button("Sign In") { showSignIn = true }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .sheet(isPresented: $showSignIn) { SignInSheetView() }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 12)
        }
    }

    // MARK: - My Designs body

    @ViewBuilder
    private var myDesignsSection: some View {
        if !auth.isSignedIn {
            VStack(spacing: 10) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 28))
                    .foregroundStyle(.tertiary)
                Text("Sign in to see your designs")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("Published packs linked to your account will appear here.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Button("Sign In") { showSignIn = true }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .padding(.horizontal)
            .sheet(isPresented: $showSignIn) {
                SignInSheetView()
            }

        } else if isLoadingMyPacks {
            ProgressView("Loading your designs…")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)

        } else if let err = myPacksError {
            Label(err, systemImage: "wifi.exclamationmark")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)

        } else if myPacks.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "tray")
                    .font(.system(size: 28))
                    .foregroundStyle(.tertiary)
                Text("No published designs yet")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("Packs you publish as @\(auth.username) will appear here.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .padding(.horizontal)

        } else {
            VStack(spacing: 1) {
                ForEach(Array(myPacks.enumerated()), id: \.element.id) { index, pack in
                    MyDesignRow(pack: pack)
                    if index < myPacks.count - 1 {
                        Divider().padding(.horizontal)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Data

    private func applyHistoryImage(_ image: NSImage) {
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

    private func loadMyPacks() async {
        guard auth.isSignedIn else { myPacks = []; return }
        isLoadingMyPacks = true
        myPacksError = nil
        do {
            let all = try await SupabaseService.fetchIconPacks()
            let lower = auth.username.lowercased()
            myPacks = all.filter { $0.author.lowercased() == lower }
        } catch {
            myPacksError = error.localizedDescription
        }
        isLoadingMyPacks = false
    }

}

// MARK: - My Design Row

private struct MyDesignRow: View {
    let pack: RemoteIconPack
    @State private var thumbnails: [NSImage] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                // Thumbnail strip
                HStack(spacing: 4) {
                    ForEach(Array(thumbnails.prefix(3).enumerated()), id: \.offset) { _, img in
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    ForEach(0 ..< max(0, min(3, pack.icons.count) - thumbnails.count), id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.1))
                            .frame(width: 40, height: 40)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(pack.name)
                            .font(.system(size: 13, weight: .semibold))
                        if let status = pack.status, status != "approved" {
                            Text(status)
                                .font(.system(size: 10, weight: .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(statusColor(status).opacity(0.12))
                                .foregroundStyle(statusColor(status))
                                .clipShape(Capsule())
                        }
                    }
                    Text("\(pack.icons.count) icon\(pack.icons.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            if let tags = pack.tags, !tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption2)
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
        .padding(.vertical, 12)
        .task { await loadThumbnails() }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "approved": return .green
        case "rejected": return .red
        default:         return .orange
        }
    }

    private func loadThumbnails() async {
        var loaded: [NSImage] = []
        for path in pack.icons.prefix(3) {
            if let img = try? await SupabaseService.fetchImage(path: path) {
                loaded.append(img)
            }
        }
        await MainActor.run { thumbnails = loaded }
    }
}


// MARK: - Saved packs store (UserDefaults)

enum SavedPacksStore {
    private static let key = "foldi_saved_pack_ids"

    static func savedIDs() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    static func isSaved(_ id: String) -> Bool { savedIDs().contains(id) }

    static func save(id: String) {
        var ids = UserDefaults.standard.stringArray(forKey: key) ?? []
        guard !ids.contains(id) else { return }
        ids.append(id)
        UserDefaults.standard.set(ids, forKey: key)
    }

    static func remove(id: String) {
        var ids = UserDefaults.standard.stringArray(forKey: key) ?? []
        ids.removeAll { $0 == id }
        UserDefaults.standard.set(ids, forKey: key)
    }

    static func toggle(id: String) {
        isSaved(id) ? remove(id: id) : save(id: id)
    }
}

// MARK: - Notification

extension Notification.Name {
    static let savedPacksChanged = Notification.Name("foldi.savedPacksChanged")
}

// MARK: - Shared section UI helpers

private struct PageSectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 8)
    }
}

private struct PageDivider: View {
    var body: some View {
        Divider()
            .padding(.horizontal)
            .padding(.vertical, 4)
    }
}

private struct PageEmptyState: View {
    let icon: String
    let message: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.tertiary)
            Text(message)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.bottom, 20)
    }
}
