import SwiftUI

struct SizePresetGrid: View {
    @Binding var selection: IconSize?

    var body: some View {
        HStack(spacing: 6) {
            ForEach(IconSize.allCases, id: \.self) { size in
                Text(size.rawValue)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(selection == size ? Color.accentColor : Color.secondary.opacity(0.15))
                    )
                    .foregroundStyle(selection == size ? .white : .primary)
                    .onTapGesture { selection = size }
            }
        }
    }
}
