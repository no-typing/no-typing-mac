import Foundation

/// Service for transcribing audio using the Groq API (OpenAI-compatible endpoint).
/// Uses Groq's hosted Whisper models for fast, cloud-based transcription.
class GroqTranscriptionService {
    static let shared = GroqTranscriptionService()
    
    // MARK: - Constants
    private let endpoint = "https://api.groq.com/openai/v1/audio/transcriptions"
    private let defaultModel = "whisper-large-v3-turbo"
    private let keychainKey = "groqAPIKey"
    
    private init() {}
    
    // MARK: - API Key Management
    
    /// Get the stored Groq API key from Keychain
    var apiKey: String? {
        return KeychainWrapper.standard.string(forKey: keychainKey)
    }
    
    /// Save the Groq API key to Keychain
    func saveAPIKey(_ key: String) {
        KeychainWrapper.standard.set(key, forKey: keychainKey)
    }
    
    /// Remove the Groq API key from Keychain
    func removeAPIKey() {
        KeychainWrapper.standard.removeObject(forKey: keychainKey)
    }
    
    /// Check if a Groq API key is configured
    var hasAPIKey: Bool {
        guard let key = apiKey else { return false }
        return !key.isEmpty
    }
    
    /// Returns a masked version of the stored API key for display (e.g. "gsk_••••••••")
    var maskedAPIKey: String {
        guard let key = apiKey, !key.isEmpty else { return "" }
        let prefix = String(key.prefix(4))
        return "\(prefix)••••••••"
    }
    
    // MARK: - Transcription
    
    /// Transcribe an audio file using the Groq API.
    /// - Parameters:
    ///   - audioURL: URL to the audio file to transcribe
    ///   - language: Optional language code (e.g. "en", "es", "fr")
    ///   - completion: Callback with the transcription result or error
    func transcribe(audioURL: URL, language: String? = nil, completion: @escaping (Result<String, Error>) -> Void) {
        print("🎙️ [Groq] Starting transcription for: \(audioURL.lastPathComponent)")
        
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            print("🎙️ [Groq] ERROR: No API key configured")
            completion(.failure(GroqError.missingAPIKey))
            return
        }
        
        print("🎙️ [Groq] Using API key: \(apiKey.prefix(4))...")
        
        // Read audio data
        let audioData: Data
        do {
            audioData = try Data(contentsOf: audioURL)
            print("🎙️ [Groq] Audio data size: \(audioData.count) bytes")
        } catch {
            print("🎙️ [Groq] ERROR reading audio: \(error)")
            completion(.failure(GroqError.audioReadError(error)))
            return
        }
        
        // Build multipart request
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        
        var body = Data()
        
        // Add file field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"recording.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add model field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(defaultModel)\r\n".data(using: .utf8)!)
        
        // Add language field if specified
        if let language = language, !language.isEmpty {
            // Convert full language name to ISO code if needed
            let langCode = Self.languageCode(from: language)
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(langCode)\r\n".data(using: .utf8)!)
            print("🎙️ [Groq] Language: \(langCode)")
        }
        
        // Add response_format field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("verbose_json\r\n".data(using: .utf8)!)
        
        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        print("🎙️ [Groq] Sending request to: \(endpoint)")
        print("🎙️ [Groq] Model: \(defaultModel)")
        print("🎙️ [Groq] Request body size: \(body.count) bytes")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("🎙️ [Groq] Network error: \(error.localizedDescription)")
                completion(.failure(GroqError.networkError(error)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("🎙️ [Groq] ERROR: Invalid response type")
                completion(.failure(GroqError.invalidResponse))
                return
            }
            
            print("🎙️ [Groq] Response status: \(httpResponse.statusCode)")
            
            guard let data = data else {
                print("🎙️ [Groq] ERROR: No response data")
                completion(.failure(GroqError.noData))
                return
            }
            
            let rawResponse = String(data: data, encoding: .utf8) ?? "<binary data>"
            print("🎙️ [Groq] Raw response: \(rawResponse)")
            
            if httpResponse.statusCode == 200 {
                // Try to parse as JSON first (verbose_json format)
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let transcription = json["text"] as? String {
                    let trimmed = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
                    print("🎙️ [Groq] ✅ Transcription (from JSON): \(trimmed)")
                    completion(.success(trimmed))
                } else if let transcription = String(data: data, encoding: .utf8) {
                    // Fallback: treat as plain text
                    let trimmed = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
                    print("🎙️ [Groq] ✅ Transcription (plain text): \(trimmed)")
                    completion(.success(trimmed))
                } else {
                    print("🎙️ [Groq] ERROR: Could not decode response")
                    completion(.failure(GroqError.decodingError))
                }
            } else {
                print("🎙️ [Groq] ERROR (\(httpResponse.statusCode)): \(rawResponse)")
                completion(.failure(GroqError.apiError(statusCode: httpResponse.statusCode, message: rawResponse)))
            }
        }.resume()
    }
    
    // MARK: - Language Code Mapping
    
    /// Convert a full language name (e.g. "english") to an ISO 639-1 code (e.g. "en")
    static func languageCode(from languageName: String) -> String {
        let mapping: [String: String] = [
            "english": "en",
            "spanish": "es",
            "french": "fr",
            "german": "de",
            "italian": "it",
            "portuguese": "pt",
            "dutch": "nl",
            "russian": "ru",
            "chinese": "zh",
            "japanese": "ja",
            "korean": "ko",
            "arabic": "ar",
            "hindi": "hi",
            "turkish": "tr",
            "polish": "pl",
            "swedish": "sv",
            "danish": "da",
            "norwegian": "no",
            "finnish": "fi",
            "czech": "cs",
            "romanian": "ro",
            "hungarian": "hu",
            "greek": "el",
            "hebrew": "he",
            "thai": "th",
            "vietnamese": "vi",
            "indonesian": "id",
            "malay": "ms",
            "ukrainian": "uk",
        ]
        
        let lowered = languageName.lowercased()
        // If already a short code, return as-is
        if lowered.count <= 3 {
            return lowered
        }
        return mapping[lowered] ?? lowered
    }
}

// MARK: - Error Types

enum GroqError: LocalizedError {
    case missingAPIKey
    case audioReadError(Error)
    case networkError(Error)
    case invalidResponse
    case noData
    case decodingError
    case apiError(statusCode: Int, message: String)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Groq API key is not configured. Please add your API key in App Settings."
        case .audioReadError(let error):
            return "Failed to read audio file: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from Groq API."
        case .noData:
            return "No data received from Groq API."
        case .decodingError:
            return "Failed to decode Groq API response."
        case .apiError(let statusCode, let message):
            return "Groq API error (\(statusCode)): \(message)"
        }
    }
}
