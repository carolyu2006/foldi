import SwiftUI

enum MainTab: String, CaseIterable {
    case customize = "Customize"
    case myCollection = "My Collection"
    case designs = "Gallery"
    case myCreation = "My Studio"
    case cart = "Cart"

    var icon: String {
        switch self {
        case .customize: "paintpalette"
        case .myCollection: "rectangle.stack.person.crop"
        case .designs: "photo.on.rectangle"
        case .myCreation: "square.grid.2x2"
        case .cart: "cart"
        }
    }
}

struct MainView: View {
    @State private var model = FolderIconModel()
    @State private var bookmarkManager = BookmarkManager()
    @State private var collectionStore = CollectionStore()
    @State private var aiConfig = AIConfig()
    @State private var authService = AppAuthService()
    @State private var showSettings = false
    @State private var selectedTab: MainTab = .customize

    var body: some View {
        Group {
            if model.selectedFolderURL == nil {
                // Welcome screen — full page drop/select
                WelcomeView(model: model, bookmarkManager: bookmarkManager)
            } else {
                // Main editor
                HStack(spacing: 0) {
                    // Left panel: preview + apply
                    VStack(alignment: .leading, spacing: 0) {

                        IconPreviewView(
                            model: model,
                            bookmarkManager: bookmarkManager
                        )

                        ApplyActionBar(
                            model: model,
                            collectionStore: collectionStore,
                            bookmarkManager: bookmarkManager
                        )
                        .padding(.top, 100)

                        Spacer()
                    }
                    .padding(.top, 60)
                    .padding(.trailing, 20)
                    .padding(.leading, 40)
                    .frame(width: 280)

                    Spacer()
                        .frame(width: 15)

                    // Right panel: tabs
                    VStack(spacing: 0) {
                        TabBar(selectedTab: $selectedTab)

                        Group {
                            switch selectedTab {
                            case .customize:
                                CustomizeTabView(model: model)
                            case .myCollection:
                                MyCollectionTabView(model: model)
                            case .designs:
                                GalleryTabView(model: model)
                            case .myCreation:
                                MyCreationTabView(model: model, collectionStore: collectionStore)
                            case .cart:
                                CartTabView()
                            }
                        }
                        .frame(maxHeight: .infinity)
                        .padding(.top, 16)
                    }
                    .frame(width: 484)
                    .environment(authService)
                }
            }
        }
        .task { await authService.refreshIfNeeded() }
        .onChange(of: model.selectedFolderURL) { oldURL, newURL in
            if oldURL == nil && newURL != nil {
                selectedTab = .customize
            }
        }
    }
}

// MARK: - Custom Tab Bar
struct TabBar: View {
@Binding var selectedTab: MainTab

@State private var cartCount: Int = SavedPacksStore.savedIDs().count

private let unselectedColor = Color(hex: "9F9F9F") ?? .gray
private let borderColor = Color(hex: "EAEAEA") ?? .gray.opacity(0.3)
private let selectedColor = Color(hex: "212121") ?? .primary

var body: some View {
    ZStack(alignment: .bottomLeading) {

        // Global border (background layer)
        Rectangle()
            .fill(borderColor)
            .frame(height: 1.5)
            .onReceive(NotificationCenter.default.publisher(for: .savedPacksChanged)) { _ in
                cartCount = SavedPacksStore.savedIDs().count
            }

        // Tabs + cart icon
        HStack(spacing: 0) {
            // Text tabs (all except cart)
            HStack(spacing: 20) {
                ForEach(MainTab.allCases.filter { $0 != .cart }, id: \.self) { tab in
                    TabBarButton(
                        title: tab.rawValue,
                        isSelected: selectedTab == tab,
                        selectedColor: selectedColor,
                        unselectedColor: unselectedColor
                    ) {
                        selectedTab = tab
                    }
                }
            }
            .padding(.leading, 16)

            Spacer()

            // Cart icon on the right
            Button {
                selectedTab = .cart
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: selectedTab == .cart ? "cart.fill" : "cart")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(selectedTab == .cart ? selectedColor : unselectedColor)
                        .padding(.vertical, 10)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(selectedTab == .cart ? selectedColor : .clear)
                                .frame(height: 1.5)
                        }

                    if cartCount > 0 {
                        Text("\(cartCount)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(Color(hex: "B11D1D") ?? .red)
                            )
                            .offset(x: 8, y: 2)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.trailing, 16)
        }
        .frame(maxWidth: .infinity)
    }
}
}

struct TabBarButton: View {
let title: String
let isSelected: Bool
let selectedColor: Color
let unselectedColor: Color
let action: () -> Void

var body: some View {
    Button(action: action) {
        Text(title)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(isSelected ? selectedColor : unselectedColor)
            .lineLimit(1)
            .fixedSize()
            .padding(.vertical, 10)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(isSelected ? selectedColor : .clear)
                    .frame(height: 1.5)
            }
    }
    .buttonStyle(.plain)
}
}
