import Foundation

class TranscriptionTranslator {
    static let shared = TranscriptionTranslator()
    
    private init() {}
    
    func translate(text: String) async throws -> String {
        guard UserDefaults.standard.bool(forKey: "enableAITranslation") else {
            return text
        }
        
        let providerString = UserDefaults.standard.string(forKey: "aiTranslationProvider") ?? "DeepL"
        let targetLanguage = UserDefaults.standard.string(forKey: "translationTargetLanguage") ?? "EN-US"
        
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedText.isEmpty { return text }
        
        let prompt = "You are a professional translator. Translate the following text to \(targetLanguage). Respond ONLY with the translation."
        
        switch providerString {
        case "DeepL":
            return try await DeepLManager.shared.translate(text: text, targetLanguage: targetLanguage)
            
        case "OpenAI":
            let model = UserDefaults.standard.string(forKey: "openaiTranslationModel") ?? "gpt-4o"
            return try await OpenAIManager.shared.improveText(prompt: prompt, text: text, model: model)
            
        case "Anthropic":
            let model = UserDefaults.standard.string(forKey: "anthropicTranslationModel") ?? "claude-3-5-sonnet-latest"
            return try await AnthropicManager.shared.improveText(prompt: prompt, text: text, model: model)
            
        case "Google":
            let key = UserDefaults.standard.string(forKey: "googleApiKey") ?? ""
            let modelUsed = UserDefaults.standard.string(forKey: "googleTranslationModel") ?? "gemini-3.1-flash-preview"
            if key.isEmpty { return text }
            return try await GeminiManager.shared.improveText(systemPrompt: prompt, userText: text, apiKey: key, model: modelUsed)
            
        case "Groq", "Deepseek", "Ollama", "Custom API endpoint":
            let extProvider: LLMProvider
            let key: String
            let url: String
            let modelUsed: String
            
            switch providerString {
            case "Groq":
                extProvider = .groq
                key = UserDefaults.standard.string(forKey: "groqApiKey") ?? ""
                url = "https://api.groq.com/openai/v1/chat/completions"
                modelUsed = UserDefaults.standard.string(forKey: "groqTranslationModel") ?? "llama-3.3-70b-versatile"
            case "Deepseek":
                extProvider = .deepseek
                key = UserDefaults.standard.string(forKey: "deepseekApiKey") ?? ""
                url = "https://api.deepseek.com/chat/completions"
                modelUsed = UserDefaults.standard.string(forKey: "deepseekTranslationModel") ?? "deepseek-chat"

            case "Ollama":
                extProvider = .ollama
                key = ""
                url = UserDefaults.standard.string(forKey: "ollamaTranslationBaseURL") ?? "http://localhost:11434/v1/chat/completions"
                modelUsed = UserDefaults.standard.string(forKey: "ollamaTranslationModel") ?? "llama3"
            default: // Custom
                extProvider = .custom
                key = UserDefaults.standard.string(forKey: "customTranslationApiKey") ?? ""
                url = UserDefaults.standard.string(forKey: "customTranslationBaseURL") ?? "https://api.openai.com/v1/chat/completions"
                modelUsed = UserDefaults.standard.string(forKey: "customTranslationModel") ?? "gpt-4"
            }
            
            return try await ExtendedLLMManager.shared.improveText(prompt: prompt, text: text, provider: extProvider, apiKey: key, baseURL: url, model: modelUsed)
            
        case "Apple":
            // Placeholder for Apple Translation framework if needed
            return text
            
        default:
            return text
        }
    }
}
