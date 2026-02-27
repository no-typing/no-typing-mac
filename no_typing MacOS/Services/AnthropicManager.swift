import Foundation

enum AnthropicModel: String, CaseIterable, Identifiable {
    case claude35Sonnet = "claude-3-5-sonnet-20240620"
    case claude3Opus = "claude-3-opus-20240229"
    case claude3Haiku = "claude-3-haiku-20240307"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .claude35Sonnet: return "Claude 3.5 Sonnet"
        case .claude3Opus: return "Claude 3 Opus"
        case .claude3Haiku: return "Claude 3 Haiku"
        }
    }
}

enum AnthropicError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(String)
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Anthropic API URL."
        case .invalidResponse:
            return "Invalid response from Anthropic."
        case .apiError(let message):
            return "Anthropic Error: \(message)"
        case .decodingError:
            return "Failed to decode Anthropic response."
        }
    }
}

class AnthropicManager {
    static let shared = AnthropicManager()
    private init() {}
    
    var hasValidKey: Bool {
        let key = UserDefaults.standard.string(forKey: "anthropicApiKey") ?? ""
        return !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    func improveText(prompt: String, text: String, model: String) async throws -> String {
        guard let apiKey = UserDefaults.standard.string(forKey: "anthropicApiKey"), !apiKey.isEmpty else {
            throw AnthropicError.apiError("No API key provided.")
        }
        
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw AnthropicError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.addValue("application/json", forHTTPHeaderField: "content-Type")
        
        let messages: [[String: Any]] = [
            ["role": "user", "content": text]
        ]
        
        let parameters: [String: Any] = [
            "model": model,
            "system": prompt,
            "max_tokens": 1024,
            "messages": messages,
            "temperature": 0.3 // Low temperature for consistent factual rewriting
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AnthropicError.invalidResponse
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if httpResponse.statusCode == 200 {
                if let contentArray = json["content"] as? [[String: Any]],
                   let first = contentArray.first,
                   let textResponse = first["text"] as? String {
                    return textResponse
                }
            } else if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
                throw AnthropicError.apiError(message)
            }
        }
        
        throw AnthropicError.decodingError
    }
}
