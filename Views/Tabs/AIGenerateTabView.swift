import SwiftUI

struct AIGenerateTabView: View {
    @Bindable var model: FolderIconModel
    var aiConfig: AIConfig
    var collectionStore: CollectionStore

    @FocusState private var promptFocused: Bool
    @State private var isScanning = false
    @State private var isDesigning = false
    @State private var isGeneratingImage = false
    @State private var scanError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Prompt section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(model.isInFeedbackMode ? "Feedback" : "Prompt")
                            .font(.headline)
                        Spacer()
                        if isScanning {
                            ProgressView().controlSize(.small)
                            Text("Analyzing...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if model.isInFeedbackMode {
                            Button {
                                model.popAIUndo()
                            } label: {
                                Image(systemName: "arrow.uturn.backward")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                            .disabled(model.aiUndoStack.isEmpty)
                            .help("Undo last AI generation")
                        }
                        Button {
                            model.promptText = ""
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .disabled(model.promptText.isEmpty)
                    }

                    PromptTextBox(text: $model.promptText, isFocused: $promptFocused)
                }

                // Action buttons
                HStack(spacing: 12) {
                    Button {
                        getAISuggestions()
                    } label: {
                        if isDesigning {
                            HStack(spacing: 4) {
                                ProgressView().controlSize(.small)
                                Text("Suggesting...")
                            }
                        } else {
                            Text("Get AI Suggestions")
                        }
                    }
                    .disabled(isDesigning || isScanning || model.promptText.isEmpty || aiConfig.designer.modelName.isEmpty)
                    .frame(maxWidth: .infinity)

                    Button {
                        generateImage()
                    } label: {
                        if isGeneratingImage {
                            HStack(spacing: 4) {
                                ProgressView().controlSize(.small)
                                Text("Generating...")
                            }
                        } else {
                            Text(model.isInFeedbackMode ? "Refine" : "Generate by AI")
                        }
                    }
                    .disabled(isGeneratingImage || isScanning || model.promptText.isEmpty || aiConfig.imageGen.apiKey.isEmpty)
                    .frame(maxWidth: .infinity)
                }
                .controlSize(.large)

                if let scanError {
                    Text(scanError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(3)
                }

                Divider()

                // AI Candidates
                AITabView(model: model, aiConfig: aiConfig, collectionStore: collectionStore)
            }
            .padding()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            promptFocused = false
        }
        .onChange(of: model.selectedFolderURL) { _, newURL in
            if newURL != nil {
                summarizeFolder()
            }
        }
    }

    // MARK: - AI Actions

    private func getAISuggestions() {
        let config = aiConfig.designer
        isDesigning = true
        scanError = nil
        Task {
            do {
                let response = try await LLMService.sendMessage(
                    system: aiConfig.systemPrompts.designer,
                    user: model.promptText,
                    config: config
                )
                print("[AI Designer] Raw LLM response:\n\(response)")
                let suggestion = try AISuggestion.parse(from: response)
                suggestion.apply(to: model)
            } catch {
                scanError = "Design error: \(error.localizedDescription)"
                print("[AI Designer] Raw response:\n\(error)")
            }
            isDesigning = false
        }
    }

    private func generateImage() {
        isGeneratingImage = true
        scanError = nil
        Task {
            do {
                model.pushAIUndo()

                var refImages: [NSImage] = []
                if !model.isInFeedbackMode {
                    if aiConfig.imageGen.includeReferenceImage {
                        refImages.append(FolderIconRenderer.render(model: model))
                    }
                    for id in model.starredCollectionIDs {
                        if let item = collectionStore.items.first(where: { $0.id == id }),
                           let img = collectionStore.image(for: item) {
                            refImages.append(img)
                        }
                    }
                    let limit = FolderIconModel.maxReferenceImages
                    if refImages.count > limit {
                        refImages = Array(refImages.shuffled().prefix(limit))
                    }
                }

                let candidates = try await generateCandidates(
                    prompt: model.promptText,
                    referenceImages: refImages,
                    config: aiConfig.imageGen,
                    systemPrompt: aiConfig.systemPrompts.imageGen,
                    previousResponseId: model.aiResponseId
                )

                let images = candidates.map(\.image)

                model.aiCandidates = images
                model.aiCandidateCollectionIDs = [:]
                model.aiResponseId = candidates.first?.responseId
                model.selectedCandidateIndex = 0
                if let first = images.first {
                    model.backgroundImage = first
                    model.useBackgroundImage = true
                }
                model.forceRender()
            } catch {
                scanError = "Image generation error: \(error.localizedDescription)"
                print("[AI ImageGen] Error: \(error)")
            }
            isGeneratingImage = false
        }
    }

    private func summarizeFolder() {
        guard let folderURL = model.selectedFolderURL else { return }
        let config = aiConfig.summarizer
        guard !config.modelName.isEmpty else {
            model.promptText = folderURL.lastPathComponent
            return
        }
        isScanning = true
        scanError = nil
        Task {
            do {
                let scanResult = await FolderScanner.scan(folderURL: folderURL)
                let response = try await LLMService.sendMessage(
                    system: aiConfig.systemPrompts.summarizer,
                    user: scanResult.fullContext,
                    config: config
                )
                model.promptText = response
            } catch {
                scanError = error.localizedDescription
                if model.promptText.isEmpty {
                    model.promptText = folderURL.lastPathComponent
                }
            }
            isScanning = false
        }
    }
}
