import SwiftUI

struct CartTabView: View {
    @Environment(AppAuthService.self) private var auth

    @State private var cartPacks: [RemoteIconPack] = []
    @State private var isLoading = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading cart…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if cartPacks.isEmpty {
                ContentUnavailableView(
                    "Your cart is empty",
                    systemImage: "cart",
                    description: Text("Save packs from the Gallery to add them here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(cartPacks) { pack in
                            CartPackSection(pack: pack) { _ in
                            } onRemove: {
                                SavedPacksStore.remove(id: pack.id)
                                NotificationCenter.default.post(name: .savedPacksChanged, object: nil)
                                cartPacks.removeAll { $0.id == pack.id }
                                if let userId = auth.userId, let token = auth.accessToken {
                                    Task { try? await SupabaseService.removeWishlistItem(userId: userId, packId: pack.id, accessToken: token) }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .task { await loadCart() }
        .onReceive(NotificationCenter.default.publisher(for: .savedPacksChanged)) { _ in
            Task { await loadCart() }
        }
    }

    private func loadCart() async {
        let ids = SavedPacksStore.savedIDs()
        guard !ids.isEmpty else { cartPacks = []; return }
        isLoading = true
        do {
            let all = try await SupabaseService.fetchIconPacks()
            cartPacks = all.filter { ids.contains($0.id) }
        } catch {
            cartPacks = []
        }
        isLoading = false
    }

}

// MARK: - Cart pack section

private struct CartPackSection: View {
    let pack: RemoteIconPack
    let onAdd: (String) -> Void
    let onRemove: () -> Void

    private let columns = [GridItem(.adaptive(minimum: 72), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(pack.name).font(.headline)
                    Text("by \(pack.author)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 6) {
                    Button {
                        onRemove()
                    } label: {
                        Image(systemName: "cart.fill.badge.minus")
                    }
                    .buttonStyle(ActionButtonStyle(isPrimary: false))

                    Button("Add to Collection") {
                        guard let first = pack.icons.first else { return }
                        onAdd(first)
                    }
                    .buttonStyle(ActionButtonStyle(isPrimary: true))
                }
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(pack.icons, id: \.self) { path in
                    RemoteIconCell(path: path) { onAdd(path) }
                }
            }
        }
    }
}
