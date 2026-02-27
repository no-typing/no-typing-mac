import Foundation

enum LLMProvider: String, CaseIterable, Identifiable {
    case groq = "Groq"
    case deepseek = "Deepseek"
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
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
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
        
        throw ExtendedLLMError.decodingError
    }
}
