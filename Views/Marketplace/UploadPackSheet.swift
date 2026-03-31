import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct UploadPackSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppAuthService.self) private var auth

    @State private var packName    = ""
    @State private var author      = ""
    @State private var tagsInput   = ""
    @State private var selectedFiles: [URL] = []
    @State private var isUploading  = false
    @State private var progress: Double = 0
    @State private var statusMessage = ""
    @State private var uploadDone   = false
    @State private var uploadError: String?
    @State private var showSignIn   = false

    private var canUpload: Bool {
        auth.isSignedIn &&
        !packName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !author.trimmingCharacters(in: .whitespaces).isEmpty &&
        !selectedFiles.isEmpty &&
        !isUploading
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // ── Header ────────────────────────────────────────────────
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Upload Icon Pack")
                        .font(.title2.weight(.semibold))
                    Text("Publish icons to the marketplace")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }

            Divider()

            if !auth.isSignedIn {
                // ── Auth gate ─────────────────────────────────────────
                VStack(spacing: 12) {
                    Image(systemName: "lock.circle")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("Sign in to publish")
                        .font(.headline)
                    Text("You need a Foldi account to upload icon packs to the marketplace.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Sign In…") { showSignIn = true }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .sheet(isPresented: $showSignIn) {
                    SignInSheetView()
                }

            } else {
                // ── Upload form ───────────────────────────────────────
                VStack(alignment: .leading, spacing: 14) {
                    // Signed-in user badge
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                        Text("Signed in as @\(auth.username)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Sign Out") { Task { await auth.signOut() } }
                            .font(.caption)
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(Color.green.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    LabeledField(label: "Pack Name") {
                        TextField("e.g. Glass Icons", text: $packName)
                            .textFieldStyle(.roundedBorder)
                    }

                    LabeledField(label: "Author") {
                        TextField("Your name or handle", text: $author)
                            .textFieldStyle(.roundedBorder)
                    }

                    LabeledField(label: "Tags") {
                        TextField("glass, minimal, dark  (comma-separated)", text: $tagsInput)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                // ── File picker ───────────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    Text("PNG Files")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        pickFiles()
                    } label: {
                        Label(selectedFiles.isEmpty ? "Choose PNG files…" : "Change selection",
                              systemImage: "folder.badge.plus")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)

                    if !selectedFiles.isEmpty {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(selectedFiles, id: \.self) { url in
                                    HStack(spacing: 6) {
                                        Image(systemName: "photo")
                                            .foregroundStyle(.secondary)
                                            .font(.caption)
                                        Text(url.lastPathComponent)
                                            .font(.caption)
                                        Spacer()
                                    }
                                }
                            }
                            .padding(8)
                        }
                        .frame(maxHeight: 100)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.07)))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2)))
                    }
                }

                // ── Progress ──────────────────────────────────────────
                if isUploading {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(value: progress)
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let err = uploadError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if uploadDone {
                    Label("Pack published! It will appear in the gallery shortly.", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.callout)
                }
            }

            Spacer()

            // ── Actions ───────────────────────────────────────────────
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(ActionButtonStyle(isPrimary: false))
                Spacer()
                if auth.isSignedIn {
                    Button("Upload") { Task { await upload() } }
                        .buttonStyle(ActionButtonStyle(isPrimary: true))
                        .disabled(!canUpload)
                }
            }
        }
        .padding(24)
        .frame(width: 420, height: 560)
        .onAppear {
            if author.isEmpty { author = auth.displayName }
        }
    }

    // MARK: - File Picker

    private func pickFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.png]
        panel.prompt = "Select Icons"
        if panel.runModal() == .OK { selectedFiles = panel.urls }
    }

    // MARK: - Upload

    private func upload() async {
        guard let accessToken = auth.accessToken,
              let userId      = auth.userId else { return }

        isUploading  = true
        uploadDone   = false
        uploadError  = nil
        progress     = 0

        let name  = packName.trimmingCharacters(in: .whitespaces)
        let auth_ = author.trimmingCharacters(in: .whitespaces)
        let tags  = tagsInput
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
        let slug  = name.lowercased().replacingOccurrences(of: " ", with: "-")

        var uploadedPaths: [String] = []
        let total = Double(selectedFiles.count)

        for (i, fileURL) in selectedFiles.enumerated() {
            statusMessage = "Uploading \(fileURL.lastPathComponent)…"
            do {
                guard let data = pngData(from: fileURL) else {
                    throw SupabaseError.httpError(0, "Could not read \(fileURL.lastPathComponent)")
                }
                let storagePath = "\(slug)/\(fileURL.lastPathComponent)"
                try await SupabaseService.uploadIcon(data: data, path: storagePath, accessToken: accessToken)
                uploadedPaths.append(storagePath)
            } catch {
                await MainActor.run {
                    uploadError = "Upload failed: \(error.localizedDescription)"
                    isUploading = false
                }
                return
            }
            await MainActor.run { progress = Double(i + 1) / total }
        }

        statusMessage = "Saving pack metadata…"
        do {
            try await SupabaseService.insertIconPack(
                name: name, author: auth_, tags: tags,
                icons: uploadedPaths, userId: userId, accessToken: accessToken
            )
        } catch {
            await MainActor.run {
                uploadError = "Metadata save failed: \(error.localizedDescription)"
                isUploading = false
            }
            return
        }

        await MainActor.run {
            isUploading   = false
            uploadDone    = true
            statusMessage = ""
        }
    }

    private func pngData(from url: URL) -> Data? {
        guard let image  = NSImage(contentsOf: url),
              let tiff   = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}

// MARK: - Labeled field helper

private struct LabeledField<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
        }
    }
}
