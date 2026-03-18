import Foundation

enum LLMError: LocalizedError {
    case noModel
    case noAPIKey
    case invalidURL
    case requestFailed(String)
    case noResponse

    var errorDescription: String? {
        switch self {
        case .noModel: "No model name configured."
        case .noAPIKey: "API key is required for this provider."
        case .invalidURL: "Invalid base URL."
        case .requestFailed(let msg): msg
        case .noResponse: "No response from LLM."
        }
    }
}

struct LLMService {
    static func sendMessage(system: String, user: String, config: LLMConfig) async throws -> String {
        guard !config.modelName.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw LLMError.noModel
        }
        if config.provider.requiresAPIKey && config.apiKey.trimmingCharacters(in: .whitespaces).isEmpty {
            throw LLMError.noAPIKey
        }

        let (request, body) = try buildRequest(system: system, user: user, config: config)
        var urlRequest = request
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else { throw LLMError.noResponse }
        guard (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw LLMError.requestFailed(msg)
        }

        return try extractResponse(from: data, provider: config.provider)
    }

    static func testConnection(config: LLMConfig) async throws -> Bool {
        _ = try await sendMessage(system: "You are a test assistant.", user: "Reply with OK.", config: config)
        return true
    }

    static func fetchOllamaModels(baseURL: String) async throws -> [String] {
        guard let url = URL(string: "\(baseURL)/api/tags") else { throw LLMError.invalidURL }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw LLMError.requestFailed("Failed to fetch Ollama models")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [[String: Any]] else {
            return []
        }
        return models.compactMap { $0["name"] as? String }.sorted()
    }

    // MARK: - Request Builders

    private static func buildRequest(system: String, user: String, config: LLMConfig) throws -> (URLRequest, [String: Any]) {
        switch config.provider {
        case .anthropic:
            return try buildAnthropicRequest(system: system, user: user, config: config)
        case .gemini:
            return try buildGeminiRequest(system: system, user: user, config: config)
        case .ollama, .openAI, .openRouter, .qwen:
            return try buildOpenAIRequest(system: system, user: user, config: config)
        }
    }

    private static func buildOpenAIRequest(system: String, user: String, config: LLMConfig) throws -> (URLRequest, [String: Any]) {
        let base = config.provider == .ollama ? config.baseURL : config.provider.defaultBaseURL
        let endpoint = config.provider == .ollama ? "\(base)/api/chat" : "\(base)/chat/completions"
        guard let url = URL(string: endpoint) else { throw LLMError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if config.provider != .ollama {
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = [
            "model": config.modelName,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
            "stream": false,
        ]
        return (request, body)
    }

    private static func buildAnthropicRequest(system: String, user: String, config: LLMConfig) throws -> (URLRequest, [String: Any]) {
        guard let url = URL(string: "\(config.provider.defaultBaseURL)/messages") else {
            throw LLMError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": config.modelName,
            "max_tokens": 256,
            "system": system,
            "messages": [
                ["role": "user", "content": user],
            ],
        ]
        return (request, body)
    }

    private static func buildGeminiRequest(system: String, user: String, config: LLMConfig) throws -> (URLRequest, [String: Any]) {
        let endpoint = "\(config.provider.defaultBaseURL)/models/\(config.modelName):generateContent?key=\(config.apiKey)"
        guard let url = URL(string: endpoint) else { throw LLMError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "systemInstruction": ["parts": [["text": system]]],
            "contents": [["parts": [["text": user]]]],
        ]
        return (request, body)
    }

    // MARK: - Response Extraction

    private static func extractResponse(from data: Data, provider: LLMProviderType) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMError.noResponse
        }

        switch provider {
        case .anthropic:
            if let content = json["content"] as? [[String: Any]],
               let text = content.first?["text"] as? String {
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        case .gemini:
            if let candidates = json["candidates"] as? [[String: Any]],
               let content = candidates.first?["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let text = parts.first?["text"] as? String {
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        case .ollama, .openAI, .openRouter, .qwen:
            if let choices = json["choices"] as? [[String: Any]],
               let message = choices.first?["message"] as? [String: Any],
               let text = message["content"] as? String {
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            // Ollama also supports top-level "message"
            if let message = json["message"] as? [String: Any],
               let text = message["content"] as? String {
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        throw LLMError.noResponse
    }
}
