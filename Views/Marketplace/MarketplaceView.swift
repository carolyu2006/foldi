import SwiftUI

/// Placeholder marketplace page — will allow browsing and downloading icon packs
struct MarketplaceView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "storefront")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.secondary)

            Text("Marketplace")
                .font(.title.weight(.medium))

            Text("Coming Soon")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("Browse and download icon packs created by the community.\nShare your own collections with others.")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
