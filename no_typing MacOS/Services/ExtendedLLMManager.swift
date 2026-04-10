import Foundation

enum LLMProvider: String, CaseIterable, Identifiable {
    case openai = "OpenAI"
    case anthropic = "Anthropic"
    case groq = "Groq"
    case deepseek = "Deepseek"
    case google = "Google"
    case xai = "xAI"
    case ollama = "Ollama"
    case custom = "Custom OpenAI Endpoint"
    
    var id: String { self.rawValue }
}

enum ExtendedLLMError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(String)
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid Endpoint URL."
        case .invalidResponse: return "Invalid response from the server."
        case .apiError(let message): return "API Error: \(message)"
        case .decodingError: return "Failed to decode the response."
        }
    }
}

class ExtendedLLMManager {
    static let shared = ExtendedLLMManager()
    private init() {}
    
    func improveText(prompt: String, text: String, provider: LLMProvider, apiKey: String, baseURL: String, model: String) async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw ExtendedLLMError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if !apiKey.isEmpty {
            if provider == .google {
                // Google's OpenAI endpoint sometimes prefers this header specifically
                request.addValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
            } else if provider == .anthropic {
                request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
                request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            } else {
                request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
        }
        
        let messages: [[String: Any]] = [
            ["role": "system", "content": prompt],
            ["role": "user", "content": text]
        ]
        
        let parameters: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": 0.3
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ExtendedLLMError.invalidResponse
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if httpResponse.statusCode == 200 {
                if let choices = json["choices"] as? [[String: Any]],
                   let first = choices.first,
                   let message = first["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    return content
                }
            } else if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
                throw ExtendedLLMError.apiError(message)
            }
        }
        
        let snippet = String(data: data.prefix(200), encoding: .utf8) ?? "binary data"
        throw ExtendedLLMError.apiError("Decoding failed (Status \(httpResponse.statusCode)). Response: \(snippet)")
    }
    
    /// Generic fetch for OpenAI-compatible providers (Groq, Deepseek, Ollama, etc.)
    func fetchAvailableModels(apiKey: String, baseURL: String, provider: LLMProvider) async throws -> [String] {
        // Derive models URL from baseURL (usually ends in /chat/completions or /v1)
        var modelsURLString = baseURL
        if modelsURLString.hasSuffix("/chat/completions") {
            modelsURLString = modelsURLString.replacingOccurrences(of: "/chat/completions", with: "/models")
        } else if modelsURLString.hasSuffix("/v1") {
            modelsURLString = modelsURLString + "/models"
        } else if provider == .ollama && !modelsURLString.contains("/models") {
            // Ollama specific handling if base is just the host
            modelsURLString = modelsURLString.replacingOccurrences(of: "/v1/chat/completions", with: "/api/tags")
        }
        
        guard let url = URL(string: modelsURLString) else {
            throw ExtendedLLMError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if !apiKey.isEmpty {
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ExtendedLLMError.invalidResponse
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // Standard OpenAI response: data[].id
            if let dataArray = json["data"] as? [[String: Any]] {
                return dataArray.compactMap { $0["id"] as? String }
            }
            // Ollama native response (if hit directly): models[].name
            if let modelsArray = json["models"] as? [[String: Any]] {
                return modelsArray.compactMap { $0["name"] as? String }
            }
        }
        
        throw ExtendedLLMError.decodingError
    }
}
