import SwiftUI

struct SignInSheetView: View {
    @Environment(AppAuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var email    = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Header ──────────────────────────────────────────────────
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(auth.isSignedIn ? "Account" : "Sign In")
                        .font(.system(size: 16, weight: .semibold))
                    Text(auth.isSignedIn
                         ? "@\(auth.username)"
                         : "Sign in to save and manage icon packs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.primary.opacity(0.3))
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider().opacity(0.5)

            if auth.isSignedIn {
                signedInView
            } else {
                signInForm
            }
        }
        .frame(width: 340)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Signed-in view

    private var signedInView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Text(auth.username.prefix(1).uppercased())
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.primary)
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text("@\(auth.username)")
                        .font(.system(size: 14, weight: .semibold))
                    Text(auth.session?.email ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Button(role: .destructive) {
                Task {
                    await auth.signOut()
                    dismiss()
                }
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Sign-in form

    private var signInForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let msg = errorMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Group {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Email")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField("you@example.com", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textContentType(.emailAddress)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("Password")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)
                        .onSubmit { Task { await submit() } }
                }
            }

            Button {
                Task { await submit() }
            } label: {
                Group {
                    if isLoading {
                        ProgressView().scaleEffect(0.75)
                            .tint(.white)
                    } else {
                        Text("Sign In")
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "212121") ?? .primary)
                        .opacity(email.isEmpty || password.isEmpty || isLoading ? 0.4 : 1.0)
                )
            }
            .buttonStyle(.plain)
            .disabled(email.isEmpty || password.isEmpty || isLoading)

            HStack(spacing: 3) {
                Text("New to Foldi?")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Sign up") {
                    NSWorkspace.shared.open(URL(string: "https://foldi.org/auth?tab=signup")!)
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundStyle(Color.primary)
                .underline()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Action

    private func submit() async {
        errorMessage = nil
        isLoading = true
        do {
            try await auth.signIn(email: email, password: password)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
