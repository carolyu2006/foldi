import Foundation

// MARK: - Text LLM Provider Types

enum LLMProviderType: String, CaseIterable, Codable {
    case ollama
    case openRouter
    case openAI
    case anthropic
    case gemini
    case qwen

    var displayName: String {
        switch self {
        case .ollama: "Ollama"
        case .openRouter: "OpenRouter"
        case .openAI: "OpenAI"
        case .anthropic: "Anthropic"
        case .gemini: "Gemini"
        case .qwen: "Qwen"
        }
    }

    var requiresAPIKey: Bool {
        self != .ollama
    }

    var defaultBaseURL: String {
        switch self {
        case .ollama: "http://localhost:11434"
        case .openRouter: "https://openrouter.ai/api/v1"
        case .openAI: "https://api.openai.com/v1"
        case .anthropic: "https://api.anthropic.com/v1"
        case .gemini: "https://generativelanguage.googleapis.com/v1beta"
        case .qwen: "https://dashscope.aliyuncs.com/compatible-mode/v1"
        }
    }
}

// MARK: - Image Generation Provider Types

enum ImageProviderType: String, CaseIterable, Codable {
    case openAI
    case gemini

    var displayName: String {
        switch self {
        case .openAI: "OpenAI (GPT Image)"
        case .gemini: "Gemini Image"
        }
    }

    var defaultModel: String {
        switch self {
        case .openAI: "gpt-5"
        case .gemini: "gemini-2.5-flash-preview-image-generation"
        }
    }
}

enum GeminiImageModel: String, CaseIterable {
    case standard = "gemini-2.5-flash-preview-image-generation"
    case pro = "gemini-2.0-flash-preview-image-generation"

    var displayName: String {
        switch self {
        case .standard: "Gemini Image (Nano Banana)"
        case .pro: "Gemini Image Pro (Nano Banana Pro)"
        }
    }
}

// MARK: - Single LLM Provider Config (reusable for summarizer & designer)

@Observable
final class LLMConfig: Identifiable {
    let id: String // persistence key prefix

    var provider: LLMProviderType {
        didSet { save("provider", provider.rawValue) }
    }
    var modelName: String {
        didSet { save("model", modelName) }
    }
    var apiKey: String {
        didSet { save("apiKey", apiKey) }
    }
    var baseURL: String {
        didSet { save("baseURL", baseURL) }
    }

    init(id: String) {
        self.id = id
        let d = UserDefaults.standard
        let savedProvider = d.string(forKey: "\(id)_provider") ?? LLMProviderType.ollama.rawValue
        self.provider = LLMProviderType(rawValue: savedProvider) ?? .ollama
        self.modelName = d.string(forKey: "\(id)_model") ?? "llama3.1"
        self.apiKey = d.string(forKey: "\(id)_apiKey") ?? ""
        self.baseURL = d.string(forKey: "\(id)_baseURL") ?? LLMProviderType.ollama.defaultBaseURL
    }

    private func save(_ key: String, _ value: String) {
        UserDefaults.standard.set(value, forKey: "\(id)_\(key)")
    }
}

// MARK: - Image Provider Config

@Observable
final class ImageGenConfig {
    var provider: ImageProviderType {
        didSet { UserDefaults.standard.set(provider.rawValue, forKey: "imagegen_provider") }
    }

    // Per-provider API keys
    var openAIApiKey: String {
        didSet { UserDefaults.standard.set(openAIApiKey, forKey: "imagegen_openai_apiKey") }
    }
    var geminiApiKey: String {
        didSet { UserDefaults.standard.set(geminiApiKey, forKey: "imagegen_gemini_apiKey") }
    }

    // Per-provider model names
    var openAIModel: String {
        didSet { UserDefaults.standard.set(openAIModel, forKey: "imagegen_openai_model") }
    }
    var geminiModel: String {
        didSet { UserDefaults.standard.set(geminiModel, forKey: "imagegen_gemini_model") }
    }

    // Shared settings
    var includeReferenceImage: Bool {
        didSet { UserDefaults.standard.set(includeReferenceImage, forKey: "imagegen_includeRef") }
    }
    var numberOfCandidates: Int {
        didSet { UserDefaults.standard.set(numberOfCandidates, forKey: "imagegen_candidates") }
    }

    /// Active API key for the currently selected provider
    var apiKey: String {
        get {
            switch provider {
            case .openAI: openAIApiKey
            case .gemini: geminiApiKey
            }
        }
        set {
            switch provider {
            case .openAI: openAIApiKey = newValue
            case .gemini: geminiApiKey = newValue
            }
        }
    }

    /// Active model name for the currently selected provider
    var modelName: String {
        get {
            switch provider {
            case .openAI: openAIModel
            case .gemini: geminiModel
            }
        }
        set {
            switch provider {
            case .openAI: openAIModel = newValue
            case .gemini: geminiModel = newValue
            }
        }
    }

    init() {
        let d = UserDefaults.standard
        let saved = d.string(forKey: "imagegen_provider") ?? ImageProviderType.openAI.rawValue
        self.provider = ImageProviderType(rawValue: saved) ?? .openAI
        self.openAIApiKey = d.string(forKey: "imagegen_openai_apiKey") ?? d.string(forKey: "imagegen_apiKey") ?? ""
        self.geminiApiKey = d.string(forKey: "imagegen_gemini_apiKey") ?? ""
        let migratedModel = d.string(forKey: "imagegen_openai_model") ?? d.string(forKey: "imagegen_model")
        // Migrate away from old invalid model names
        if let m = migratedModel, m.hasPrefix("gpt-image") {
            self.openAIModel = "gpt-5"
        } else {
            self.openAIModel = migratedModel ?? "gpt-5"
        }
        self.geminiModel = d.string(forKey: "imagegen_gemini_model") ?? GeminiImageModel.standard.rawValue
        self.includeReferenceImage = d.object(forKey: "imagegen_includeRef") as? Bool ?? true
        self.numberOfCandidates = d.object(forKey: "imagegen_candidates") as? Int ?? 1
    }
}

// MARK: - System Prompts (user-editable, persisted)

@Observable
final class AISystemPrompts {
    static let defaultSummarizer = """
        You will receive a folder's structure and file snippets. \
        Respond with ONLY a short phrase (under 10 words) saying what this folder is. \
        Examples: "React e-commerce web app", "Machine learning research project", \
        "Personal travel photos", "iOS Swift game". \
        No full sentences. No periods. No explanation. Just the phrase.
        """

    static let defaultDesigner = """
        You are a folder icon designer for macOS. Given a description of a folder's contents, \
        design a visually meaningful folder icon.

        RULES:
        - "themeColor": ONE hex color representing the folder's theme. The app will derive \
        lighter/darker front/back colors automatically.
        - "text.content": 1-2 words max — the central idea of this folder \
        (e.g. "Code", "Music", "ML", "Web App", "Game Dev", "UI Kit", "API", "Photos").
        - For the icon, suggest ALL THREE options. The app will load all of them and activate \
        the highest-priority one. Set "priority" to rank them.

        Icon options:
        1. emoji — any single emoji (e.g. "💻", "🎵", "📊")
        2. sfSymbol — an Apple SF Symbol name. Common ones: \
        terminal.fill, doc.text.fill, photo.fill, music.note, globe, cpu, \
        chart.bar.fill, hammer.fill, paintbrush.fill, book.fill, heart.fill, \
        star.fill, gamecontroller.fill, cart.fill, airplane, graduationcap.fill, \
        wrench.and.screwdriver.fill, network, server.rack, video.fill, camera.fill, \
        flask.fill, brain.head.profile, lock.fill, lightbulb.fill, map.fill, swift
        3. fontAwesome — a Font Awesome icon name. Common ones: \
        code, terminal, database, server, github, python, js, react, docker, git, swift, \
        file-code, book, music, film, camera, image, palette, paint-brush, \
        flask, atom, microscope, graduation-cap, brain, chart-bar, chart-line, \
        briefcase, dollar-sign, shopping-cart, store, envelope, globe, plane, car, \
        home, heart, gamepad, lock, shield-alt, star, fire, bolt, wrench, tools, \
        cloud, calendar, search, link, bug, robot, bicycle, chess, puzzle-piece

        Return ONLY valid JSON with this schema:
        {
          "themeColor": "#hex",
          "text": {
            "content": "OneWord",
            "position": "bottomCenter",
            "size": "md",
            "color": "#FFFFFF",
            "font": "SF Pro",
            "weight": "medium"
          },
          "icon": {
            "emoji": "🎵",
            "sfSymbol": "music.note",
            "fontAwesome": "music",
            "priority": ["fontAwesome", "sfSymbol", "emoji"],
            "position": "topCenter",
            "size": "lg"
          }
        }

        No markdown fences. No explanation. ONLY the JSON.
        """

    static let defaultImageGen = """
        Generate a complete macOS folder icon. Include the folder shape and \
        redesign it based on the given reference and prompt. \
        Square format, 1024x1024 pixels. Simple, medium, recognizable at small sizes. \
        Use a transparent background. \
        {user_prompt}
        """

    var summarizer: String {
        didSet { UserDefaults.standard.set(summarizer, forKey: "sysprompt_summarizer") }
    }
    var designer: String {
        didSet { UserDefaults.standard.set(designer, forKey: "sysprompt_designer") }
    }
    var imageGen: String {
        didSet { UserDefaults.standard.set(imageGen, forKey: "sysprompt_imagegen") }
    }

    private static let promptVersion = 7 // bump this to reset all persisted prompts to new defaults

    init() {
        let d = UserDefaults.standard
        let savedVersion = d.integer(forKey: "sysprompt_version")
        if savedVersion < Self.promptVersion {
            // Defaults changed — reset persisted prompts
            d.removeObject(forKey: "sysprompt_summarizer")
            d.removeObject(forKey: "sysprompt_designer")
            d.removeObject(forKey: "sysprompt_imagegen")
            d.set(Self.promptVersion, forKey: "sysprompt_version")
        }
        self.summarizer = d.string(forKey: "sysprompt_summarizer") ?? Self.defaultSummarizer
        self.designer = d.string(forKey: "sysprompt_designer") ?? Self.defaultDesigner
        self.imageGen = d.string(forKey: "sysprompt_imagegen") ?? Self.defaultImageGen
    }
}

// MARK: - Top-Level AI Config (holds everything)

@Observable
final class AIConfig {
    let summarizer: LLMConfig
    let designer: LLMConfig
    let imageGen: ImageGenConfig
    let systemPrompts: AISystemPrompts

    init() {
        self.summarizer = LLMConfig(id: "summarizer")
        self.designer = LLMConfig(id: "designer")
        self.imageGen = ImageGenConfig()
        self.systemPrompts = AISystemPrompts()
    }
}
