import SwiftUI

struct AIProviderSettingsView: View {
    @Bindable var aiConfig: AIConfig

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 1. Summarizer
                GroupBox {
                    LLMProviderConfigView(
                        config: aiConfig.summarizer,
                        label: "Quick, lightweight model for scanning folder contents and generating descriptions."
                    )
                    SystemPromptEditor(
                        title: "Summarizer System Prompt",
                        text: Binding(
                            get: { aiConfig.systemPrompts.summarizer },
                            set: { aiConfig.systemPrompts.summarizer = $0 }
                        ),
                        defaultText: AISystemPrompts.defaultSummarizer
                    )
                } label: {
                    Label("Summarizer", systemImage: "text.magnifyingglass")
                        .font(.headline)
                }

                // 2. Designer
                GroupBox {
                    LLMProviderConfigView(
                        config: aiConfig.designer,
                        label: "Larger model that generates a JSON payload describing icon settings (colors, emoji, text, placement)."
                    )
                    SystemPromptEditor(
                        title: "Designer System Prompt",
                        text: Binding(
                            get: { aiConfig.systemPrompts.designer },
                            set: { aiConfig.systemPrompts.designer = $0 }
                        ),
                        defaultText: AISystemPrompts.defaultDesigner
                    )
                } label: {
                    Label("Designer", systemImage: "paintbrush")
                        .font(.headline)
                }

                // 3. Asset Generator (Image)
                GroupBox {
                    ImageProviderConfigView(config: aiConfig.imageGen)

                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Include current design as reference", isOn: Binding(
                            get: { aiConfig.imageGen.includeReferenceImage },
                            set: { aiConfig.imageGen.includeReferenceImage = $0 }
                        ))
                        .font(.caption)
                        Stepper(
                            "Candidates: \(aiConfig.imageGen.numberOfCandidates)",
                            value: Binding(
                                get: { aiConfig.imageGen.numberOfCandidates },
                                set: { aiConfig.imageGen.numberOfCandidates = $0 }
                            ),
                            in: 1...4
                        )
                        .frame(maxWidth: 300)
                    }
                    .padding(.top, 4)

                    SystemPromptEditor(
                        title: "Image Generation Prompt Template",
                        text: Binding(
                            get: { aiConfig.systemPrompts.imageGen },
                            set: { aiConfig.systemPrompts.imageGen = $0 }
                        ),
                        defaultText: AISystemPrompts.defaultImageGen
                    )
                } label: {
                    Label("Asset Generator", systemImage: "photo")
                        .font(.headline)
                }
            }
            .padding()
        }
    }
}

// MARK: - Reusable LLM Provider Config

struct LLMProviderConfigView: View {
    @Bindable var config: LLMConfig
    var label: String

    @State private var testResult: TestResult?
    @State private var isTesting = false
    @State private var ollamaModels: [String] = []
    @State private var isLoadingModels = false

    enum TestResult {
        case success
        case failure(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Provider", selection: $config.provider) {
                ForEach(LLMProviderType.allCases, id: \.self) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }
            .frame(maxWidth: 300)

            HStack {
                TextField("Model Name", text: $config.modelName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)
            }

            if config.provider == .ollama {
                HStack {
                    if isLoadingModels {
                        ProgressView().controlSize(.small)
                        Text("Loading...").foregroundStyle(.secondary).font(.caption)
                    } else if !ollamaModels.isEmpty {
                        Picker("Available", selection: $config.modelName) {
                            Text("Select a model").tag("")
                            ForEach(ollamaModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                        .frame(maxWidth: 300)
                    }
                    Button {
                        loadOllamaModels()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .disabled(isLoadingModels)
                }

                TextField("Base URL", text: $config.baseURL)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)
            }

            if config.provider.requiresAPIKey {
                SecureField("API Key", text: $config.apiKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)
            }

            HStack {
                Button("Test Connection") { testConnection() }
                    .disabled(isTesting || config.modelName.isEmpty)
                if isTesting {
                    ProgressView().controlSize(.small)
                }
                if let result = testResult {
                    switch result {
                    case .success:
                        Label("Connected", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .failure(let msg):
                        Label(msg, systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .lineLimit(2)
                            .font(.caption)
                    }
                }
            }
        }
        .onAppear {
            if config.provider == .ollama { loadOllamaModels() }
        }
        .onChange(of: config.provider) { _, newValue in
            testResult = nil
            ollamaModels = []
            if newValue == .ollama { loadOllamaModels() }
        }
    }

    private func loadOllamaModels() {
        isLoadingModels = true
        Task {
            ollamaModels = (try? await LLMService.fetchOllamaModels(baseURL: config.baseURL)) ?? []
            isLoadingModels = false
        }
    }

    private func testConnection() {
        isTesting = true
        testResult = nil
        Task {
            do {
                _ = try await LLMService.testConnection(config: config)
                testResult = .success
            } catch {
                testResult = .failure(error.localizedDescription)
            }
            isTesting = false
        }
    }
}

// MARK: - Image Provider Config

struct ImageProviderConfigView: View {
    @Bindable var config: ImageGenConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Text-to-image model for generating folder icon artwork.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Active Provider", selection: $config.provider) {
                ForEach(ImageProviderType.allCases, id: \.self) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }
            .frame(maxWidth: 300)

            Divider()

            // OpenAI settings
            Text("OpenAI")
                .font(.subheadline).fontWeight(.medium)
            TextField("Model (e.g. gpt-5, gpt-4.1)", text: $config.openAIModel)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 300)
            SecureField("OpenAI API Key", text: $config.openAIApiKey)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 300)

            Divider()

            // Gemini settings
            Text("Gemini")
                .font(.subheadline).fontWeight(.medium)
            Picker("Model", selection: $config.geminiModel) {
                ForEach(GeminiImageModel.allCases, id: \.rawValue) { model in
                    Text(model.displayName).tag(model.rawValue)
                }
            }
            .frame(maxWidth: 300)
            SecureField("Gemini API Key", text: $config.geminiApiKey)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 300)
        }
    }
}

// MARK: - System Prompt Editor

struct SystemPromptEditor: View {
    let title: String
    @Binding var text: String
    let defaultText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Button("Reset to Default") {
                    text = defaultText
                }
                .font(.caption)
                .disabled(text == defaultText)
            }
            TextEditor(text: $text)
                .font(.system(.caption, design: .monospaced))
                .frame(height: 100)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.3))
                )
        }
        .padding(.top, 8)
    }
}
