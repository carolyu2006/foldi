import SwiftUI

struct PromptTextBox: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .textBackgroundColor))
            RoundedRectangle(cornerRadius: 8)
                .stroke(isFocused.wrappedValue ? Color.accentColor : Color.secondary.opacity(0.3),
                        lineWidth: isFocused.wrappedValue ? 2 : 1)

            if text.isEmpty && !isFocused.wrappedValue {
                Text("Describe the icon you want...")
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $text)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(6)
                .focused(isFocused)
        }
        .frame(height: 72)
    }
}
