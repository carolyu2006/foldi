import SwiftUI

struct CollectionEmptyView: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)
            Text("No saved icons yet")
                .font(.callout)
                .foregroundStyle(.tertiary)
            Text("Icons will appear here when you apply them to a folder")
                .font(.caption)
                .foregroundStyle(.quaternary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
