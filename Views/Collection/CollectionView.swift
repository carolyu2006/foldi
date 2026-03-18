import SwiftUI

/// Main collection page — shows groups and ungrouped items
struct CollectionView: View {
    var store: CollectionStore
    @State private var selectedGroup: CollectionGroup?
    @State private var showNewGroupSheet = false
    @State private var newGroupName = ""

    var body: some View {
        VStack(spacing: 0) {
            collectionHeader
            Divider()
            collectionBody
        }
        .sheet(isPresented: $showNewGroupSheet) {
            NewGroupSheet(name: $newGroupName) {
                if !newGroupName.isEmpty {
                    store.addGroup(name: newGroupName)
                    newGroupName = ""
                }
                showNewGroupSheet = false
            }
        }
    }

    @ViewBuilder
    private var collectionHeader: some View {
        HStack {
            Text("Collection")
                .font(.title2.weight(.medium))
            Spacer()
            Button {
                showNewGroupSheet = true
            } label: {
                Image(systemName: "folder.badge.plus")
            }
            .help("New Group")
        }
        .padding()
    }

    @ViewBuilder
    private var collectionBody: some View {
        if store.items.isEmpty && store.groups.isEmpty {
            CollectionEmptyView()
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    // Groups
                    ForEach(store.groups) { group in
                        CollectionGroupSection(store: store, group: group)
                    }

                    // Ungrouped items
                    let ungrouped = store.items(in: nil)
                    if !ungrouped.isEmpty {
                        CollectionGroupSection(store: store, group: nil, title: "Ungrouped")
                    }
                }
                .padding()
            }
        }
    }
}
