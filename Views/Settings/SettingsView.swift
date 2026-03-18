import SwiftUI

struct SettingsView: View {
    var bookmarkManager: BookmarkManager
    var aiConfig: AIConfig
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            TabView {
                GeneralSettingsView()
                    .tabItem { Label("General", systemImage: "gear") }
                PermissionsSettingsView(bookmarkManager: bookmarkManager)
                    .tabItem { Label("Permissions", systemImage: "lock.shield") }
                AIProviderSettingsView(aiConfig: aiConfig)
                    .tabItem { Label("AI Providers", systemImage: "brain") }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
}
