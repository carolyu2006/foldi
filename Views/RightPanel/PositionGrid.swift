import SwiftUI

struct PositionGrid: View {
    @Binding var selection: IconPosition

    private let rows: [[IconPosition]] = [
        [.topLeft, .topCenter, .topRight],
        [.middleLeft, .center, .middleRight],
        [.bottomLeft, .bottomCenter, .bottomRight],
    ]

    var body: some View {
        VStack(spacing: 4) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(row, id: \.self) { pos in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(selection == pos ? Color.accentColor : Color.secondary.opacity(0.2))
                            .frame(width: 32, height: 32)
                            .onTapGesture { selection = pos }
                    }
                }
            }
        }
    }
}
