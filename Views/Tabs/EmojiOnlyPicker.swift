import SwiftUI
import AppKit

struct EmojiOnlyPicker: View {
    @Binding var selectedEmoji: String
    var onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            EmojiButton(emoji: selectedEmoji, size: 52, fontSize: 36) { picked in
                selectedEmoji = picked
                onChange()
            }
        }
    }
}

// MARK: - Reusable Emoji Button (opens native macOS Character Viewer)

struct EmojiButton: View {
    let emoji: String
    var size: CGFloat = 48
    var fontSize: CGFloat = 28
    var onSelect: (String) -> Void

    @State private var isHovered = false

    var body: some View {
        EmojiInputWrapper(emoji: emoji, fontSize: fontSize, onSelect: onSelect)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.secondary.opacity(0.15) : Color.secondary.opacity(0.1))
            )
            .onHover { isHovered = $0 }
            .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

// MARK: - NSViewRepresentable to capture emoji from Character Viewer

struct EmojiInputWrapper: NSViewRepresentable {
    let emoji: String
    let fontSize: CGFloat
    let onSelect: (String) -> Void

    func makeNSView(context: Context) -> EmojiCaptureTextField {
        let field = EmojiCaptureTextField()
        field.onEmojiInsert = onSelect
        field.stringValue = emoji
        field.font = NSFont.systemFont(ofSize: fontSize)
        field.alignment = .center
        field.isBezeled = false
        field.drawsBackground = false
        field.isEditable = true
        field.isSelectable = true
        field.focusRingType = .none
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ nsView: EmojiCaptureTextField, context: Context) {
        nsView.stringValue = emoji
        nsView.onEmojiInsert = onSelect
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var onSelect: (String) -> Void

        init(onSelect: @escaping (String) -> Void) {
            self.onSelect = onSelect
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            let text = field.stringValue
            // Extract the last emoji character entered
            if let lastScalar = text.unicodeScalars.last,
               lastScalar.properties.isEmoji && lastScalar.value > 0x23 {
                // Find the full emoji (may be multi-scalar)
                if let lastChar = text.last {
                    let emoji = String(lastChar)
                    onSelect(emoji)
                    field.stringValue = emoji
                }
            }
        }
    }
}

class EmojiCaptureTextField: NSTextField {
    var onEmojiInsert: ((String) -> Void)?

    override func mouseDown(with event: NSEvent) {
        self.window?.makeFirstResponder(self)
        NSApp.orderFrontCharacterPalette(nil)
    }

    override func textDidChange(_ notification: Notification) {
        let text = stringValue
        if let lastChar = text.last {
            let emoji = String(lastChar)
            if emoji.unicodeScalars.first?.properties.isEmoji == true,
               (emoji.unicodeScalars.first?.value ?? 0) > 0x23 {
                onEmojiInsert?(emoji)
                stringValue = emoji
            }
        }
    }
}
