import Foundation

enum CloudTranscriptionProvider: String, CaseIterable, Identifiable {
    case openai = "OpenAI Whisper"
    case elevenlabs = "ElevenLabs"
    case deepgram = "Deepgram"
    case groq = "Groq Whisper"
    case custom = "Custom API endpoint"
    
    var id: String { self.rawValue }
}

enum CloudTranscriptionError: Error, LocalizedError {
    case invalidAPIKey
    case invalidURL
    case fileTooLarge
    case networkError(Error)
    case decodingError(Error)
    case apiError(String)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey: return "Missing or invalid API key for the selected provider."
        case .invalidURL: return "Invalid provider API URL."
        case .fileTooLarge: return "The audio file exceeds the upload limit for this provider."
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .decodingError(let error): return "Parsing failed: \(error.localizedDescription)"
        case .apiError(let message): return "API Error: \(message)"
        case .unknown: return "An unknown error occurred during cloud transcription."
        }
    }
}

class CloudTranscriptionManager {
    static let shared = CloudTranscriptionManager()
    private init() {}
    
    // Config properties reading from UserDefaults natively
    var openAIApiKey: String { UserDefaults.standard.string(forKey: "cloudOpenAIApiKey") ?? "" }
    var elevenLabsApiKey: String { UserDefaults.standard.string(forKey: "cloudElevenLabsApiKey") ?? "" }
    var deepgramApiKey: String { UserDefaults.standard.string(forKey: "cloudDeepgramApiKey") ?? "" }
    var groqApiKey: String { UserDefaults.standard.string(forKey: "cloudGroqApiKey") ?? "" }
    var customURL: String { UserDefaults.standard.string(forKey: "cloudCustomURL") ?? "" }
    var customApiKey: String { UserDefaults.standard.string(forKey: "cloudCustomApiKey") ?? "" }
    
    var openAIModel: String { UserDefaults.standard.string(forKey: "cloudOpenAIModel") ?? "whisper-1" }
    var elevenLabsModel: String { UserDefaults.standard.string(forKey: "cloudElevenLabsModel") ?? "scribe_v1" }
    var deepgramModel: String { UserDefaults.standard.string(forKey: "cloudDeepgramModel") ?? "nova-2" }
    var groqModel: String { UserDefaults.standard.string(forKey: "cloudGroqModel") ?? "whisper-large-v3-turbo" }
    var customModel: String { UserDefaults.standard.string(forKey: "cloudCustomModel") ?? "whisper-1" }

    func transcribe(audioURL: URL, provider: CloudTranscriptionProvider, language: String? = nil) async throws -> [WhisperTranscriptionSegment] {
        switch provider {
        case .deepgram:
            return try await transcribeDeepgram(audioURL: audioURL, language: language)
        case .elevenlabs:
            return try await transcribeElevenLabs(audioURL: audioURL, language: language)
        case .openai:
            return try await transcribeOpenAI(audioURL: audioURL, language: language)
        case .groq:
             return try await transcribeGroq(audioURL: audioURL, language: language)
        case .custom:
             return try await transcribeCustom(audioURL: audioURL, language: language)
        }
    }
    
    // MARK: - Auth Testing
    func testConnection(for provider: CloudTranscriptionProvider, apiKey: String, customURL: String = "") async throws -> Bool {
        switch provider {
        case .openai:
            guard let url = URL(string: "https://api.openai.com/v1/models") else { return false }
            var req = URLRequest(url: url)
            req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            let (_, resp) = try await URLSession.shared.data(for: req)
            return (resp as? HTTPURLResponse)?.statusCode == 200
        case .deepgram:
            guard let url = URL(string: "https://api.deepgram.com/v1/projects") else { return false }
            var req = URLRequest(url: url)
            req.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
            let (_, resp) = try await URLSession.shared.data(for: req)
            return (resp as? HTTPURLResponse)?.statusCode == 200
        case .elevenlabs:
            guard let url = URL(string: "https://api.elevenlabs.io/v1/models") else { return false }
            var req = URLRequest(url: url)
            req.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
            let (_, resp) = try await URLSession.shared.data(for: req)
            return (resp as? HTTPURLResponse)?.statusCode == 200
        case .groq:
            guard let url = URL(string: "https://api.groq.com/openai/v1/models") else { return false }
            var req = URLRequest(url: url)
            req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            let (_, resp) = try await URLSession.shared.data(for: req)
            return (resp as? HTTPURLResponse)?.statusCode == 200
        case .custom:
            return URL(string: customURL) != nil
        }
    }
    
    // MARK: - Deepgram (Diarization supported natively)
    private func transcribeDeepgram(audioURL: URL, language: String?) async throws -> [WhisperTranscriptionSegment] {
        guard !deepgramApiKey.isEmpty else { throw CloudTranscriptionError.invalidAPIKey }
        var urlStr = "https://api.deepgram.com/v1/listen?smart_format=true&diarize=true&punctuate=true&model=\(deepgramModel)"
        if let lang = language, lang != "auto" {
            urlStr += "&language=\(lang)"
        }
        guard let url = URL(string: urlStr) else { throw CloudTranscriptionError.invalidURL }
        
        let fileData = try Data(contentsOf: audioURL)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Token \(deepgramApiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = fileData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw CloudTranscriptionError.unknown }
        
        if httpResponse.statusCode != 200 {
            let errorMsg = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw CloudTranscriptionError.apiError(errorMsg)
        }
        
        // Deepgram JSON parsing
        do {
            let result = try JSONDecoder().decode(DeepgramResponse.self, from: data)
            let words = result.results.channels.first?.alternatives.first?.words ?? []
            
            // Re-stitch words into speaker segments
            var segments: [WhisperTranscriptionSegment] = []
            var currentSpeaker: Int? = nil
            var currentWords: [DeepgramWord] = []
            
            for word in words {
                if currentSpeaker == nil {
                    currentSpeaker = word.speaker
                }
                
                if word.speaker != currentSpeaker {
                    // Flush segment
                    if !currentWords.isEmpty {
                        let text = currentWords.map { $0.punctuated_word }.joined(separator: " ")
                        let startTime = currentWords.first!.start
                        let endTime = currentWords.last!.end
                        segments.append(WhisperTranscriptionSegment(startTime: startTime, endTime: endTime, text: text, translatedText: nil, speaker: "Speaker \(currentSpeaker!)", isStarred: false))
                    }
                    currentSpeaker = word.speaker
                    currentWords = [word]
                } else {
                    currentWords.append(word)
                }
            }
            
            // Flush remaining
            if !currentWords.isEmpty {
                let text = currentWords.map { $0.punctuated_word }.joined(separator: " ")
                let startTime = currentWords.first!.start
                let endTime = currentWords.last!.end
                segments.append(WhisperTranscriptionSegment(startTime: startTime, endTime: endTime, text: text, translatedText: nil, speaker: "Speaker \(currentSpeaker ?? 0)", isStarred: false))
            }
            
            // Fallback: if no word-level data, use full transcript as single segment
            if segments.isEmpty {
                let fullText = result.results.channels.first?.alternatives.first?.transcript ?? ""
                if !fullText.isEmpty {
                    segments.append(WhisperTranscriptionSegment(startTime: 0, endTime: 0, text: fullText, translatedText: nil, speaker: nil, isStarred: false))
                }
            }
            
            return segments
        } catch {
            throw CloudTranscriptionError.decodingError(error)
        }
    }
    
    // MARK: - ElevenLabs
    private func transcribeElevenLabs(audioURL: URL, language: String?) async throws -> [WhisperTranscriptionSegment] {
        guard !elevenLabsApiKey.isEmpty else { throw CloudTranscriptionError.invalidAPIKey }
        guard let url = URL(string: "https://api.elevenlabs.io/v1/speech-to-text") else { throw CloudTranscriptionError.invalidURL }
        
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(elevenLabsApiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Model
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(elevenLabsModel)\r\n".data(using: .utf8)!)
        
        // File
        let fileData = try Data(contentsOf: audioURL)
        let filename = audioURL.lastPathComponent
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/mpeg\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Enable diarization
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"diarize\"\r\n\r\n".data(using: .utf8)!)
        body.append("true\r\n".data(using: .utf8)!)
        
        // Timestamps granularity
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"timestamps_granularity\"\r\n\r\n".data(using: .utf8)!)
        body.append("word\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw CloudTranscriptionError.unknown }
        
        if httpResponse.statusCode != 200 {
            let errorMsg = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw CloudTranscriptionError.apiError(errorMsg)
        }
        
        do {
            let result = try JSONDecoder().decode(ElevenLabsResponse.self, from: data)
            
            // Re-stitch words into speaker segments
            var segments: [WhisperTranscriptionSegment] = []
            var currentSpeaker: String? = nil
            var currentWords: [ElevenLabsWord] = []
            
            for word in result.words {
                let speaker = word.speaker_id ?? "unknown"
                if currentSpeaker == nil { currentSpeaker = speaker }
                
                if speaker != currentSpeaker {
                    if !currentWords.isEmpty {
                        let text = currentWords.map { $0.text }.joined(separator: " ")
                        let startTime = currentWords.first!.start
                        let endTime = currentWords.last!.end
                        segments.append(WhisperTranscriptionSegment(startTime: startTime, endTime: endTime, text: text, translatedText: nil, speaker: currentSpeaker, isStarred: false))
                    }
                    currentSpeaker = speaker
                    currentWords = [word]
                } else {
                    currentWords.append(word)
                }
            }
            
            // Flush remaining
            if !currentWords.isEmpty {
                let text = currentWords.map { $0.text }.joined(separator: " ")
                let startTime = currentWords.first!.start
                let endTime = currentWords.last!.end
                segments.append(WhisperTranscriptionSegment(startTime: startTime, endTime: endTime, text: text, translatedText: nil, speaker: currentSpeaker, isStarred: false))
            }
            
            // If no word-level data, fall back to full text as one segment
            if segments.isEmpty && !result.text.isEmpty {
                segments.append(WhisperTranscriptionSegment(startTime: 0, endTime: 0, text: result.text, translatedText: nil, speaker: nil, isStarred: false))
            }
            
            return segments
        } catch {
            throw CloudTranscriptionError.decodingError(error)
        }
    }
    
    // MARK: - OpenAI 
    private func transcribeOpenAI(audioURL: URL, language: String?) async throws -> [WhisperTranscriptionSegment] {
        guard !openAIApiKey.isEmpty else { throw CloudTranscriptionError.invalidAPIKey }
        return try await transcribeWhisperCompatible(audioURL: audioURL, endpoint: "https://api.openai.com/v1/audio/transcriptions", apiKey: openAIApiKey, model: openAIModel, language: language)
    }

    // MARK: - Groq
    private func transcribeGroq(audioURL: URL, language: String?) async throws -> [WhisperTranscriptionSegment] {
        guard !groqApiKey.isEmpty else { throw CloudTranscriptionError.invalidAPIKey }
        return try await transcribeWhisperCompatible(audioURL: audioURL, endpoint: "https://api.groq.com/openai/v1/audio/transcriptions", apiKey: groqApiKey, model: groqModel, language: language)
    }
    
    private func transcribeCustom(audioURL: URL, language: String?) async throws -> [WhisperTranscriptionSegment] {
        guard !customURL.isEmpty else { throw CloudTranscriptionError.invalidURL }
        return try await transcribeWhisperCompatible(audioURL: audioURL, endpoint: customURL, apiKey: customApiKey, model: customModel, language: language)
    }
    
    // MARK: - Generic OpenAI-Compatible Whisper Multipart Helper
    private func transcribeWhisperCompatible(audioURL: URL, endpoint: String, apiKey: String, model: String = "whisper-1", language: String? = nil) async throws -> [WhisperTranscriptionSegment] {
        guard let url = URL(string: endpoint) else { throw CloudTranscriptionError.invalidURL }
        
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Model
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(model)\r\n".data(using: .utf8)!)
        
        // Response format
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("verbose_json\r\n".data(using: .utf8)!)
        
        // Language (if specified)
        if let lang = language, lang != "auto" {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(lang)\r\n".data(using: .utf8)!)
        }
        
        // File
        let fileData = try Data(contentsOf: audioURL)
        let filename = audioURL.lastPathComponent
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/mpeg\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw CloudTranscriptionError.unknown }
        
        if httpResponse.statusCode != 200 {
            let errorMsg = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw CloudTranscriptionError.apiError(errorMsg)
        }
        
        do {
            let result = try JSONDecoder().decode(OpenAITranscriptionResponse.self, from: data)
            if result.segments.isEmpty {
                // API returned text-only, no segments — create a single segment from the full text
                if !result.text.isEmpty {
                    return [WhisperTranscriptionSegment(startTime: 0, endTime: 0, text: result.text, translatedText: nil, speaker: nil, isStarred: false)]
                }
                return []
            }
            return result.segments.map { segment in
                WhisperTranscriptionSegment(startTime: segment.start, endTime: segment.end, text: segment.text, translatedText: nil, speaker: nil, isStarred: false)
            }
        } catch {
            throw CloudTranscriptionError.decodingError(error)
        }
    }
}

// MARK: - Response Models

fileprivate struct OpenAITranscriptionResponse: Codable {
    let text: String
    let segments: [OpenAISegment]
    
    enum CodingKeys: String, CodingKey {
        case text, segments
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decode(String.self, forKey: .text)
        segments = (try? container.decode([OpenAISegment].self, forKey: .segments)) ?? []
    }
}

fileprivate struct OpenAISegment: Codable {
    let id: Int
    let start: Double
    let end: Double
    let text: String
}

fileprivate struct DeepgramResponse: Codable {
    let results: DeepgramResults
}

fileprivate struct DeepgramResults: Codable {
    let channels: [DeepgramChannel]
}

fileprivate struct DeepgramChannel: Codable {
    let alternatives: [DeepgramAlternative]
}

fileprivate struct DeepgramAlternative: Codable {
    let transcript: String
    let words: [DeepgramWord]
}

fileprivate struct DeepgramWord: Codable {
    let word: String
    let punctuated_word: String
    let start: Double
    let end: Double
    let speaker: Int?
}

fileprivate struct ElevenLabsResponse: Codable {
    let text: String
    let words: [ElevenLabsWord]
    
    enum CodingKeys: String, CodingKey {
        case text
        case words
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decode(String.self, forKey: .text)
        words = (try? container.decode([ElevenLabsWord].self, forKey: .words)) ?? []
    }
}

fileprivate struct ElevenLabsWord: Codable {
    let text: String
    let start: Double
    let end: Double
    let speaker_id: String?
    let type: String?
}
