import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

class TranscriptionCleaner {
    static let shared = TranscriptionCleaner()
    
    private let queue = DispatchQueue(label: "com.no_typing.transcriptionCleaner")
    
    private init() {}
    
    /// Clean up transcribed text by removing filler words and making it concise
    func cleanTranscription(_ rawText: String) async throws -> String {
        // Skip cleaning if text is empty or very short
        let trimmedText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedText.isEmpty || trimmedText.count < 3 {
            return trimmedText
        }

        print("Cleaning transcription: \(rawText)")
        
        // Get the selected language from UserDefaults
        let selectedLanguageCode = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "auto"
        let selectedTone = UserDefaults.standard.string(forKey: "selectedTone") ?? "professional"
        
        // Map language codes to language names
        let languageNames: [String: String] = [
            "en": "English",
            "zh": "Chinese",
            "de": "German",
            "es": "Spanish",
            "ru": "Russian",
            "ko": "Korean",
            "fr": "French",
            "ja": "Japanese",
            "pt": "Portuguese",
            "tr": "Turkish",
            "pl": "Polish",
            "it": "Italian",
            "vi": "Vietnamese",
            "nl": "Dutch",
            "fa": "Persian",
            "ar": "Arabic",
            "auto": "English" // Default to English for auto
        ]
        
        let languageName = languageNames[selectedLanguageCode] ?? "English"
        
        // Create tone-specific instructions
        let toneInstructions: String
        switch selectedTone {
        // Standard tones
        case "professional":
            toneInstructions = "- Ensuring a clear, professional tone suitable for business communication"
        case "friendly":
            toneInstructions = "- Creating a warm, friendly, and approachable tone while maintaining clarity"
        case "casual":
            toneInstructions = "- Using relaxed, conversational language as if speaking with a colleague or friend"
        case "concise":
            toneInstructions = "- Making the text as brief and to-the-point as possible without losing meaning"
            
        // Generational tones
        case "genz":
            toneInstructions = "- Writing in the style of Gen Z communication with current slang and internet culture references"
        case "millennial":
            toneInstructions = "- Capturing millennial communication style with characteristic humor and cultural references"
        case "boomer":
            toneInstructions = "- Using more formal, traditional communication style with complete sentences and proper structure"
        case "internet":
            toneInstructions = "- Embracing internet culture communication with lowercase aesthetic and high-energy expressions"
            
        // Professional archetypes
        case "techbro":
            toneInstructions = "- Writing in Silicon Valley startup culture style with business buzzwords and entrepreneurial energy"
        case "academic":
            toneInstructions = "- Using scholarly, verbose language appropriate for academic discourse"
        case "sports":
            toneInstructions = "- Adopting an energetic sports commentary style with dynamic descriptions"
        case "news":
            toneInstructions = "- Writing in clear, authoritative news anchor style with attention-grabbing presentation"
        case "motivational":
            toneInstructions = "- Using uplifting, empowering language that inspires and encourages"
            
        // Creative styles
        case "shakespeare":
            toneInstructions = "- Writing in Elizabethan English with poetic flair and dramatic expression"
        case "noir":
            toneInstructions = "- Adopting film noir detective style with atmospheric and metaphorical language"
        case "fantasy":
            toneInstructions = "- Using medieval fantasy language style as if in an epic adventure"
        case "scifi":
            toneInstructions = "- Writing with futuristic, technical language appropriate for science fiction"
        case "pirate":
            toneInstructions = "- Adopting seafaring pirate dialect with nautical terminology"
            
        // Mood-based tones
        case "passive":
            toneInstructions = "- Using subtly passive-aggressive communication style with underlying tension"
        case "dramatic":
            toneInstructions = "- Making communication overly theatrical and emotionally heightened"
        case "sarcastic":
            toneInstructions = "- Employing dry wit and ironic observations while maintaining clarity"
        case "wholesome":
            toneInstructions = "- Writing with gentle, nurturing encouragement and genuine kindness"
        case "conspiracy":
            toneInstructions = "- Adopting a conspiracy theorist communication style with suspicious undertones"
            
        // Regional flavors
        case "southern":
            toneInstructions = "- Writing with Southern charm, warmth, and hospitality in communication style"
        case "british":
            toneInstructions = "- Using British English with sophisticated and proper communication style"
        case "surfer":
            toneInstructions = "- Adopting laid-back California surfer communication style"
        case "newyork":
            toneInstructions = "- Writing in direct, no-nonsense New York communication style"
            
        // Unique concepts
        case "corporate":
            toneInstructions = "- Using formal corporate email communication style with business etiquette"
        case "mom":
            toneInstructions = "- Writing in the characteristic style of parent text messages with unique formatting"
        case "fortune":
            toneInstructions = "- Creating mysterious, philosophical statements in fortune cookie style"
        case "infomercial":
            toneInstructions = "- Writing with excessive enthusiasm and sales pitch energy"
        case "robot":
            toneInstructions = "- Using mechanical, overly literal communication style of an AI or robot"
            
        default:
            toneInstructions = "- Ensuring a clear, professional tone"
        }
        
        let prompt = """
        You are a \(languageName) teacher helping improve written communication. Your student has provided the text below.
        
        Please correct their text by:
        - Fixing spelling and grammar errors
        - Improving sentence structure
        - Removing filler words (um, uh, ah, like, you know, so, actually, basically, literally, I mean, well)
        \(toneInstructions)
        
        Output only the corrected text in proper \(languageName). Do not include explanations or teaching notes.
        
        Student's text: \(rawText)
        """
        
        do {
            let rewriteProviderString = UserDefaults.standard.string(forKey: "aiRewriteProvider") ?? "Apple Intelligence"
            
            // Models
            let openaiModel = UserDefaults.standard.string(forKey: "openaiModelSelection") ?? "gpt-4o"
            let anthropicModel = UserDefaults.standard.string(forKey: "anthropicModelSelection") ?? "claude-3-5-sonnet-latest"
            
            let groqModel = UserDefaults.standard.string(forKey: "groqModel") ?? "llama3-70b-8192"
            let deepseekModel = UserDefaults.standard.string(forKey: "deepseekModel") ?? "deepseek-chat"
            let ollamaModel = UserDefaults.standard.string(forKey: "ollamaModel") ?? "llama3"
            let customModel = UserDefaults.standard.string(forKey: "customLLMModel") ?? "gpt-4"
            
            // Keys
            let openAIApiKey = UserDefaults.standard.string(forKey: "openaiApiKey") ?? ""
            let anthropicApiKey = UserDefaults.standard.string(forKey: "anthropicApiKey") ?? ""
            let groqApiKey = UserDefaults.standard.string(forKey: "groqApiKey") ?? ""
            let deepseekApiKey = UserDefaults.standard.string(forKey: "deepseekApiKey") ?? ""
            let ollamaBaseURL = UserDefaults.standard.string(forKey: "ollamaBaseURL") ?? "http://localhost:11434/v1/chat/completions"
            let customBaseURL = UserDefaults.standard.string(forKey: "customLLMBaseURL") ?? "https://api.openai.com/v1/chat/completions"
            let customApiKey = UserDefaults.standard.string(forKey: "customLLMApiKey") ?? ""
            
            let response: String
            
            print("✨ [AI Rewrite] Starting rewrite using: \(rewriteProviderString)")
            print("📝 [AI Rewrite] Input: \"\(rawText)\"")
            
            switch rewriteProviderString {
            case "OpenAI":
                if openAIApiKey.isEmpty { return trimmedText }
                response = try await OpenAIManager.shared.improveText(prompt: prompt, text: rawText, model: openaiModel)
                
            case "Anthropic":
                if anthropicApiKey.isEmpty { return trimmedText }
                response = try await AnthropicManager.shared.improveText(prompt: prompt, text: rawText, model: anthropicModel)
                
            case "Groq", "Deepseek", "Ollama", "Custom API endpoint":
                let extProvider: LLMProvider
                let key: String
                let url: String
                let modelUsed: String
                
                switch rewriteProviderString {
                case "Groq":
                    extProvider = .groq
                    key = groqApiKey
                    url = "https://api.groq.com/openai/v1/chat/completions"
                    modelUsed = groqModel
                case "Deepseek":
                    extProvider = .deepseek
                    key = deepseekApiKey
                    url = "https://api.deepseek.com/chat/completions"
                    modelUsed = deepseekModel
                case "Ollama":
                    extProvider = .ollama
                    key = ""
                    url = ollamaBaseURL
                    modelUsed = ollamaModel
                default: 
                    extProvider = .custom
                    key = customApiKey
                    url = customBaseURL
                    modelUsed = customModel
                }
                
                if (extProvider == .groq || extProvider == .deepseek) && key.isEmpty {
                    return trimmedText
                }
                
                response = try await ExtendedLLMManager.shared.improveText(prompt: prompt, text: rawText, provider: extProvider, apiKey: key, baseURL: url, model: modelUsed)
                
            case "Google":
                let googleApiKey = UserDefaults.standard.string(forKey: "googleApiKey") ?? ""
                let googleModel = UserDefaults.standard.string(forKey: "googleModel") ?? "gemini-3.1-flash-preview"
                if googleApiKey.isEmpty { return trimmedText }
                response = try await GeminiManager.shared.improveText(systemPrompt: prompt, userText: rawText, apiKey: googleApiKey, model: googleModel)
                
            default: // Apple Intelligence
                #if canImport(FoundationModels)
                    if #available(macOS 15.1, *) {
                        let session = LanguageModelSession()
                        let result = try await session.respond(to: prompt)
                        response = result.content
                    } else {
                        return trimmedText
                    }
                #else
                    return trimmedText
                #endif
            }
            
            let cleanedText = response.trimmingCharacters(in: .whitespacesAndNewlines)
            
            print("✅ [AI Rewrite] Completed! Provider: \(rewriteProviderString)")
            print("📤 [AI Rewrite] Output: \"\(cleanedText)\"")
            
            return cleanedText.isEmpty ? trimmedText : cleanedText
        } catch {
            print("⚠️ TranscriptionCleaner: Failed to clean text - \(error.localizedDescription)")
            // Return original text if cleaning fails
            return trimmedText
        }
    }
    
    /// Check if the cleaning service should be considered available
    func isAvailable() -> Bool {
        let providerString = UserDefaults.standard.string(forKey: "aiRewriteProvider") ?? "Apple Intelligence"
        
        // If using a cloud provider, it's always "available" (provided there's an API key)
        if providerString != "Apple Intelligence" {
            return true
        }
        
        #if canImport(FoundationModels)
        if #available(macOS 15.1, *) {
            return true
        }
        #endif
        return false
    }
}

