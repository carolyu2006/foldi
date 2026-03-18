import SwiftUI

struct SFSymbolPickerView: View {
    @Binding var selection: String
    @State private var searchText = ""

    private let symbols = [
        "star.fill", "heart.fill", "folder.fill", "doc.fill", "gear",
        "house.fill", "music.note", "photo", "video", "gamecontroller.fill",
        "paintbrush.fill", "hammer.fill", "wrench.fill", "scissors",
        "book.fill", "bookmark.fill", "flag.fill", "bell.fill", "tag.fill",
        "bolt.fill", "flame.fill", "leaf.fill", "drop.fill", "snowflake",
        "sun.max.fill", "moon.fill", "cloud.fill", "globe", "map.fill",
        "lock.fill", "key.fill", "shield.fill", "eye.fill", "hand.thumbsup.fill",
        "person.fill", "crown.fill", "trophy.fill", "gift.fill", "cart.fill",
        "cpu", "desktopcomputer", "terminal.fill", "externaldrive.fill",
    ]

    var filteredSymbols: [String] {
        if searchText.isEmpty { return symbols }
        return symbols.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack {
            TextField("Search symbols...", text: $searchText)
                .textFieldStyle(.roundedBorder)

            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(36)), count: 8), spacing: 6) {
                    ForEach(filteredSymbols, id: \.self) { name in
                        Image(systemName: name)
                            .font(.title3)
                            .frame(width: 32, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selection == name ? Color.accentColor.opacity(0.3) : Color.clear)
                            )
                            .onTapGesture { selection = name }
                    }
                }
            }
            .frame(maxHeight: 200)
        }
    }
}
