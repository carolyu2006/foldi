import SwiftUI

struct AITabView: View {
    @Bindable var model: FolderIconModel
    var aiConfig: AIConfig
    var collectionStore: CollectionStore

    @State private var feedbackText: String = ""
    @State private var isRefining = false
    @State private var isRegenerating = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if model.aiCandidates.isEmpty && !isRegenerating {
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("Click \"Generate by AI\" to start")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else if isRegenerating {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Generating...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    Text("Candidates")
                        .font(.headline)

                    let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(Array(model.aiCandidates.enumerated()), id: \.offset) { index, candidate in
                            candidateThumbnail(index: index, candidate: candidate)
                        }
                    }

                    // Feedback field
                    if model.isInFeedbackMode {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Feedback")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            TextField("Describe changes...", text: $feedbackText)
                                .textFieldStyle(.roundedBorder)

                            HStack(spacing: 8) {
                                Button {
                                    refine()
                                } label: {
                                    if isRefining {
                                        HStack(spacing: 4) {
                                            ProgressView().controlSize(.small)
                                            Text("Refining...")
                                        }
                                    } else {
                                        Text("Refine")
                                    }
                                }
                                .disabled(isRefining || feedbackText.isEmpty)

                                Button("Regenerate") {
                                    regenerate()
                                }
                                .disabled(isRefining || isRegenerating)

                                Button {
                                    model.popAIUndo()
                                } label: {
                                    Image(systemName: "arrow.uturn.backward")
                                }
                                .disabled(model.aiUndoStack.isEmpty)

                                Button("Clear") {
                                    model.clearAIConversation()
                                    feedbackText = ""
                                }
                            }
                            .controlSize(.small)
                        }
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .lineLimit(3)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func candidateThumbnail(index: Int, candidate: NSImage) -> some View {
        let isInCollection = isCandidateInCollection(candidate, at: index)
        Image(nsImage: candidate)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(minHeight: 80)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(model.selectedCandidateIndex == index ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .overlay(alignment: .topTrailing) {
                if isInCollection {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                        .padding(4)
                }
            }
            .onTapGesture {
                model.selectedCandidateIndex = index
                model.backgroundImage = candidate
                model.useBackgroundImage = true
                model.forceRender()
            }
            .contextMenu {
                if isInCollection {
                    Button("Remove from Collection") {
                        removeFromCollection(at: index)
                    }
                } else {
                    Button("Add to Collection") {
                        addToCollection(candidate, at: index)
                    }
                }
            }
    }

    /// Check if this candidate has a corresponding starred collection item
    private func isCandidateInCollection(_ candidate: NSImage, at index: Int) -> Bool {
        // We track by storing the collection item ID when added
        // Use the candidateCollectionIDs mapping
        return candidateCollectionID(at: index) != nil
    }

    /// Find the collection item ID for a candidate at index, if it was saved
    private func candidateCollectionID(at index: Int) -> UUID? {
        // Check all starred IDs to find one whose image matches
        for id in model.starredCollectionIDs {
            if let item = collectionStore.items.first(where: { $0.id == id }) {
                // Item exists in collection
                return item.id
            }
        }
        // Fallback: check by tag stored per-candidate
        return model.aiCandidateCollectionIDs[index]
    }

    private func addToCollection(_ image: NSImage, at index: Int) {
        let name = "AI Generated \(index + 1)"
        let item = collectionStore.addItem(name: name, image: image)
        model.starredCollectionIDs.insert(item.id)
        model.aiCandidateCollectionIDs[index] = item.id
    }

    private func removeFromCollection(at index: Int) {
        guard let itemID = model.aiCandidateCollectionIDs[index],
              let item = collectionStore.items.first(where: { $0.id == itemID }) else { return }
        model.starredCollectionIDs.remove(itemID)
        model.aiCandidateCollectionIDs.removeValue(forKey: index)
        collectionStore.removeItem(item)
    }

    private func refine() {
        guard !feedbackText.isEmpty else { return }
        isRefining = true
        errorMessage = nil
        let feedback = feedbackText
        Task {
            do {
                model.pushAIUndo()
                let result = try await ImageGenerationService.generate(
                    prompt: feedback,
                    referenceImages: [],
                    config: aiConfig.imageGen,
                    systemPrompt: aiConfig.systemPrompts.imageGen,
                    previousResponseId: model.aiResponseId
                )
                let image = result.image
                model.aiResponseId = result.responseId
                model.aiCandidates = [image]
                model.aiCandidateCollectionIDs = [:]
                model.selectedCandidateIndex = 0
                model.backgroundImage = image
                model.useBackgroundImage = true
                model.promptText = feedback
                feedbackText = ""
                model.forceRender()
            } catch {
                errorMessage = error.localizedDescription
            }
            isRefining = false
        }
    }

    private func regenerate() {
        isRegenerating = true
        errorMessage = nil
        Task {
            do {
                model.pushAIUndo()
                model.clearAIConversation()

                let refImages = gatherReferenceImages()

                let candidates = try await generateCandidates(
                    prompt: model.promptText,
                    referenceImages: refImages,
                    config: aiConfig.imageGen,
                    systemPrompt: aiConfig.systemPrompts.imageGen
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
                errorMessage = error.localizedDescription
            }
            isRegenerating = false
        }
    }

    /// Gather reference images from starred collection items, limited to maxReferenceImages.
    /// If provider has lower limit, randomly sample down.
    private func gatherReferenceImages() -> [NSImage] {
        var images: [NSImage] = []

        // First: optionally include current design as reference
        if aiConfig.imageGen.includeReferenceImage {
            images.append(FolderIconRenderer.render(model: model))
        }

        // Then: add starred collection items
        let starredIDs = Array(model.starredCollectionIDs)
        for id in starredIDs {
            if let item = collectionStore.items.first(where: { $0.id == id }),
               let img = collectionStore.image(for: item) {
                images.append(img)
            }
        }

        // Enforce provider limit
        let limit = FolderIconModel.maxReferenceImages
        if images.count > limit {
            images = Array(images.shuffled().prefix(limit))
        }

        return images
    }
}

func generateCandidates(
    prompt: String,
    referenceImages: [NSImage] = [],
    config: ImageGenConfig,
    systemPrompt: String,
    previousResponseId: String? = nil
) async throws -> [ImageGenResult] {
    let count = max(1, min(4, config.numberOfCandidates))
    if count == 1 {
        let result = try await ImageGenerationService.generate(
            prompt: prompt, referenceImages: referenceImages,
            config: config, systemPrompt: systemPrompt,
            previousResponseId: previousResponseId
        )
        return [result]
    }

    return try await withThrowingTaskGroup(of: ImageGenResult.self) { group in
        for _ in 0..<count {
            group.addTask {
                try await ImageGenerationService.generate(
                    prompt: prompt, referenceImages: referenceImages,
                    config: config, systemPrompt: systemPrompt,
                    previousResponseId: previousResponseId
                )
            }
        }
        var results: [ImageGenResult] = []
        for try await result in group {
            results.append(result)
        }
        return results
    }
}
