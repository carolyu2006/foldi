import SwiftUI

struct HistoryTabView: View {
    var store: CollectionStore

    private let columns = [
        GridItem(.adaptive(minimum: 72), spacing: 8)
    ]

    var body: some View {
        if store.items.isEmpty {
            ContentUnavailableView("No History",
                                   systemImage: "clock",
                                   description: Text("Saved icons will appear here."))
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(store.items) { item in
                        CollectionItemCell(store: store, item: item)
                    }
                }
            }
        }
    }
}
