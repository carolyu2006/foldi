import SwiftUI

struct ColorSwatchGrid: View {
    let colors: [Color]
    var onSelect: (Color) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(28)), count: 7), spacing: 8) {
            ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                Circle()
                    .fill(color)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle().stroke(Color.primary.opacity(0.3), lineWidth: 1)
                    )
                    .onTapGesture { onSelect(color) }
                    .contentShape(Circle())
            }
        }
    }
}
