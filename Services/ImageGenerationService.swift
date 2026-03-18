import AppKit
import Foundation

enum ImageGenError: LocalizedError {
    case noAPIKey
    case invalidURL
    case requestFailed(String)
    case noImageInResponse

    var errorDescription: String? {
        switch self {
        case .noAPIKey: "API key is required."
        case .invalidURL: "Invalid API URL."
        case .requestFailed(let msg): msg
        case .noImageInResponse: "No image found in API response."
        }
    }
}

struct ImageGenResult {
    let image: NSImage
    let responseId: String
    let revisedPrompt: String?
}

struct ImageGenerationService {

    /// Main entry point. Routes to OpenAI Responses API or Gemini generateContent.
    static func generate(
        prompt: String,
        referenceImages: [NSImage] = [],
        config: ImageGenConfig,
        systemPrompt: String,
        previousResponseId: String? = nil
    ) async throws -> ImageGenResult {
        guard !config.apiKey.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ImageGenError.noAPIKey
        }

        let fullPrompt = systemPrompt.replacingOccurrences(of: "{user_prompt}", with: prompt)

        switch config.provider {
        case .openAI:
            return try await generateOpenAI(
                prompt: fullPrompt, referenceImages: referenceImages,
                config: config, previousResponseId: previousResponseId
            )
        case .gemini:
            return try await generateGemini(
                prompt: fullPrompt, referenceImages: referenceImages,
                config: config, previousResponseId: previousResponseId
            )
        }
    }

    // MARK: - OpenAI Responses API

    private static func generateOpenAI(
        prompt: String, referenceImages: [NSImage],
        config: ImageGenConfig, previousResponseId: String?
    ) async throws -> ImageGenResult {
        let url = URL(string: "https://api.openai.com/v1/responses")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120

        let input: Any
        if !referenceImages.isEmpty && previousResponseId == nil {
            // First turn with reference images: multi-part input
            var contentParts: [[String: Any]] = []
            for refImage in referenceImages {
                if let pngData = refImage.pngData() {
                    let b64 = pngData.base64EncodedString()
                    contentParts.append([
                        "type": "input_image",
                        "image_url": "data:image/png;base64,\(b64)"
                    ])
                }
            }
            contentParts.append(["type": "input_text", "text": prompt])
            input = [["role": "user", "content": contentParts] as [String: Any]]
        } else {
            input = prompt
        }

        var body: [String: Any] = [
            "model": config.modelName,
            "input": input,
            "tools": [["type": "image_generation"] as [String: Any]],
            "stream": false
        ]

        if let prevId = previousResponseId {
            body["previous_response_id"] = prevId
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ImageGenError.noImageInResponse
        }
        let responseId = json["id"] as? String ?? ""
        guard let output = json["output"] as? [[String: Any]] else {
            throw ImageGenError.noImageInResponse
        }
        for item in output {
            guard let type = item["type"] as? String, type == "image_generation_call" else { continue }
            if let b64 = item["result"] as? String,
               let imgData = Data(base64Encoded: b64),
               let image = NSImage(data: imgData) {
                return ImageGenResult(image: image, responseId: responseId,
                                     revisedPrompt: item["revised_prompt"] as? String)
            }
        }
        throw ImageGenError.noImageInResponse
    }

    // MARK: - Gemini generateContent

    private static func generateGemini(
        prompt: String, referenceImages: [NSImage],
        config: ImageGenConfig, previousResponseId: String?
    ) async throws -> ImageGenResult {
        let model = config.modelName.isEmpty ? "gemini-2.5-flash-preview-image-generation" : config.modelName
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(config.apiKey)"
        guard let url = URL(string: endpoint) else { throw ImageGenError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        // Build parts: reference images first, then text prompt
        var parts: [[String: Any]] = []

        // Add reference images (Gemini supports up to 6 object reference images)
        for refImage in referenceImages {
            if let pngData = refImage.pngData() {
                parts.append([
                    "inline_data": [
                        "mime_type": "image/png",
                        "data": pngData.base64EncodedString()
                    ] as [String: Any]
                ])
            }
        }

        // Add transparent background instruction
        let geminiPrompt = prompt + "\nIMPORTANT: The background must be transparent."
        parts.append(["text": geminiPrompt])

        let body: [String: Any] = [
            "contents": [["parts": parts]],
            "generationConfig": [
                "responseModalities": ["TEXT", "IMAGE"]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)

        // Parse Gemini response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let responseParts = content["parts"] as? [[String: Any]] else {
            throw ImageGenError.noImageInResponse
        }

        for part in responseParts {
            if let inlineData = part["inlineData"] as? [String: Any],
               let mimeType = inlineData["mimeType"] as? String,
               mimeType.hasPrefix("image/"),
               let b64 = inlineData["data"] as? String,
               let imgData = Data(base64Encoded: b64),
               let image = NSImage(data: imgData) {
                // Gemini doesn't have response IDs like OpenAI, use empty string
                return ImageGenResult(image: image, responseId: "", revisedPrompt: nil)
            }
        }

        throw ImageGenError.noImageInResponse
    }

    // MARK: - Helpers

    private static func validateHTTPResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw ImageGenError.requestFailed("No HTTP response")
        }
        guard (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw ImageGenError.requestFailed(msg)
        }
    }
}

// MARK: - NSImage helper

private extension NSImage {
    func pngData() -> Data? {
        guard let tiff = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
