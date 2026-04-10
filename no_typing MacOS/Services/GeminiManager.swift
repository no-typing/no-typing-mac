import Foundation

enum GeminiError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(String)
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid Gemini API URL."
        case .invalidResponse: return "Invalid response from Google servers."
        case .apiError(let message): return "Gemini API Error: \(message)"
        case .decodingError: return "Failed to decode the Gemini response."
        }
    }
}

class GeminiManager {
    static let shared = GeminiManager()
    private init() {}
    
    /// Latest Google Generative AI API Implementation (April 2026)
    func improveText(systemPrompt: String, userText: String, apiKey: String, model: String) async throws -> String {
        // Primary native endpoint for Gemini 3.x
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
        
        guard let url = URL(string: urlString) else {
            throw GeminiError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "X-goog-api-key")
        
        // Native Gemini 'contents' schema
        let parameters: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": userText]
                    ]
                ]
            ],
            "system_instruction": [
                "parts": [
                    ["text": systemPrompt]
                ]
            ],
            "generation_config": [
                "temperature": 0.3,
                "topP": 0.95,
                "topK": 40,
                "maxOutputTokens": 8192,
                "responseMimeType": "text/plain"
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if httpResponse.statusCode == 200 {
                // Parse native Gemini format: candidates -> content -> parts -> text
                if let candidates = json["candidates"] as? [[String: Any]],
                   let first = candidates.first,
                   let content = first["content"] as? [String: Any],
                   let parts = content["parts"] as? [[String: Any]],
                   let firstPart = parts.first,
                   let text = firstPart["text"] as? String {
                    return text
                }
            } else if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
                throw GeminiError.apiError(message)
            }
        }
        
        let snippet = String(data: data.prefix(200), encoding: .utf8) ?? "binary data"
        throw GeminiError.apiError("Decoding failed (Status \(httpResponse.statusCode)). Response: \(snippet)")
    }
    
    /// Fetch current available models from Google
    func fetchAvailableModels(apiKey: String) async throws -> [String] {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models?key=\(apiKey)"
        guard let url = URL(string: urlString) else { throw GeminiError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GeminiError.invalidResponse
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let models = json["models"] as? [[String: Any]] {
            return models.compactMap { dict -> String? in
                guard let name = dict["name"] as? String else { return nil }
                // Strip "models/" prefix if it exists
                return name.replacingOccurrences(of: "models/", with: "")
            }
        }
        
        throw GeminiError.decodingError
    }
}
