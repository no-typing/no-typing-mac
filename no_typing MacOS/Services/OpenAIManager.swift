import Foundation

enum OpenAIModel: String, CaseIterable, Identifiable {
    case gpt4o = "gpt-4o"
    case gpt4oMini = "gpt-4o-mini"
    case gpt4Turbo = "gpt-4-turbo"
    case gpt4 = "gpt-4"
    case gpt35Turbo = "gpt-3.5-turbo"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .gpt4o: return "GPT-4o"
        case .gpt4oMini: return "GPT-4o Mini"
        case .gpt4Turbo: return "GPT-4 Turbo"
        case .gpt4: return "GPT-4"
        case .gpt35Turbo: return "GPT-3.5 Turbo"
        }
    }
}

enum OpenAIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(String)
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid OpenAI API URL."
        case .invalidResponse:
            return "Invalid response from OpenAI."
        case .apiError(let message):
            return "OpenAI Error: \(message)"
        case .decodingError:
            return "Failed to decode OpenAI response."
        }
    }
}

class OpenAIManager {
    static let shared = OpenAIManager()
    private init() {}
    
    var hasValidKey: Bool {
        let key = UserDefaults.standard.string(forKey: "openaiApiKey") ?? ""
        return !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    func improveText(prompt: String, text: String, model: String) async throws -> String {
        guard let apiKey = UserDefaults.standard.string(forKey: "openaiApiKey"), !apiKey.isEmpty else {
            throw OpenAIError.apiError("No API key provided.")
        }
        
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw OpenAIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let messages: [[String: Any]] = [
            ["role": "system", "content": prompt],
            ["role": "user", "content": text]
        ]
        
        let parameters: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": 0.3 // Low temperature for consistent factual rewriting
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
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
                throw OpenAIError.apiError(message)
            }
        }
        
        throw OpenAIError.decodingError
    }
}
