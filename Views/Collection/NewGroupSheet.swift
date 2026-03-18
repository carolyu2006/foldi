import SwiftUI

struct NewGroupSheet: View {
    @Binding var name: String
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("New Group")
                .font(.headline)

            TextField("Group name", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)

            HStack {
                Button("Cancel") {
                    name = ""
                    onDone()
                }
                .keyboardShortcut(.cancelAction)

                Button("Create") {
                    onDone()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty)
            }
        }
        .padding(24)
    }
}
