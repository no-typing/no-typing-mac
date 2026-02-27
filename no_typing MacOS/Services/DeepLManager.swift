import Foundation

enum DeepLError: Error, LocalizedError {
    case invalidURL
    case invalidAPIKey
    case networkError(Error)
    case decodingError(Error)
    case apiError(String)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid DeepL API URL."
        case .invalidAPIKey: return "Please enter a valid DeepL API key in Settings."
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .decodingError(let error): return "Failed to decode response: \(error.localizedDescription)"
        case .apiError(let message): return "DeepL API Error: \(message)"
        case .unknown: return "An unknown error occurred during translation."
        }
    }
}

class DeepLManager {
    static let shared = DeepLManager()
    
    private let userDefaultsKey = "deeplApiKey"
    
    var apiKey: String {
        get { UserDefaults.standard.string(forKey: userDefaultsKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: userDefaultsKey) }
    }
    
    var hasValidKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private init() {}
    
    func translate(text: String, targetLanguage: String) async throws -> String {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            throw DeepLError.invalidAPIKey
        }
        
        // DeepL Free API URL vs Pro API URL
        let baseURLString = key.hasSuffix(":fx") ? "https://api-free.deepl.com/v2/translate" : "https://api.deepl.com/v2/translate"
        
        guard let url = URL(string: baseURLString) else {
            throw DeepLError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("DeepL-Auth-Key \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let parameters: [String: Any] = [
            "text": [text],
            "target_lang": targetLanguage
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
        } catch {
            throw DeepLError.unknown
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeepLError.unknown
        }
        
        if httpResponse.statusCode != 200 {
            if httpResponse.statusCode == 403 {
                throw DeepLError.apiError("Authorization failed. Please check your API key.")
            } else if httpResponse.statusCode == 456 {
                throw DeepLError.apiError("Quota exceeded. The translation limit of your account has been reached.")
            }
            throw DeepLError.apiError("HTTP \(httpResponse.statusCode)")
        }
        
        do {
            let result = try JSONDecoder().decode(DeepLResponse.self, from: data)
            if let translation = result.translations.first {
                return translation.text
            } else {
                throw DeepLError.apiError("No translations returned.")
            }
        } catch {
            throw DeepLError.decodingError(error)
        }
    }
    
    func translate(texts: [String], targetLanguage: String) async throws -> [String] {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            throw DeepLError.invalidAPIKey
        }
        
        // DeepL Free API URL vs Pro API URL
        let baseURLString = key.hasSuffix(":fx") ? "https://api-free.deepl.com/v2/translate" : "https://api.deepl.com/v2/translate"
        
        guard let url = URL(string: baseURLString) else {
            throw DeepLError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("DeepL-Auth-Key \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let parameters: [String: Any] = [
            "text": texts,
            "target_lang": targetLanguage
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
        } catch {
            throw DeepLError.unknown
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeepLError.unknown
        }
        
        if httpResponse.statusCode != 200 {
            if httpResponse.statusCode == 403 {
                throw DeepLError.apiError("Authorization failed. Please check your API key.")
            } else if httpResponse.statusCode == 456 {
                throw DeepLError.apiError("Quota exceeded. The translation limit of your account has been reached.")
            }
            throw DeepLError.apiError("HTTP \(httpResponse.statusCode)")
        }
        
        do {
            let result = try JSONDecoder().decode(DeepLResponse.self, from: data)
            return result.translations.map { $0.text }
        } catch {
            throw DeepLError.decodingError(error)
        }
    }
}

// MARK: - API Response Models
fileprivate struct DeepLResponse: Codable {
    let translations: [DeepLTranslation]
}

fileprivate struct DeepLTranslation: Codable {
    let detectedSourceLanguage: String
    let text: String
    
    enum CodingKeys: String, CodingKey {
        case detectedSourceLanguage = "detected_source_language"
        case text
    }
}
