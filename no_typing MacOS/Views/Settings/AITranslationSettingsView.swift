import SwiftUI

enum TranslationProvider: String, CaseIterable, Identifiable {
    case apple = "Apple"
    case deepl = "DeepL"
    case openai = "OpenAI"
    case anthropic = "Anthropic"
    case groq = "Groq"
    case deepseek = "Deepseek"
    case google = "Google"
    case ollama = "Ollama"
    case custom = "Custom API endpoint"
    
    var id: String { self.rawValue }
}

struct AITranslationSettingsView: View {
    @AppStorage("enableAITranslation") private var useAITranslation: Bool = false
    @AppStorage("aiTranslationProvider") private var translationProviderString: String = TranslationProvider.deepl.rawValue
    
    // API Keys
    @AppStorage("deeplApiKey") private var deeplApiKey: String = ""
    @AppStorage("openaiApiKey") private var openAIApiKey: String = ""
    @AppStorage("anthropicApiKey") private var anthropicApiKey: String = ""
    @AppStorage("groqApiKey") private var groqApiKey: String = ""
    @AppStorage("deepseekApiKey") private var deepseekApiKey: String = ""
    @AppStorage("googleApiKey") private var googleApiKey: String = ""
    
    // Models
    @AppStorage("openaiTranslationModel") private var openaiModel: String = "gpt-4o"
    @AppStorage("anthropicTranslationModel") private var anthropicModel: String = "claude-3-5-sonnet-latest"
    @AppStorage("groqTranslationModel") private var groqModel: String = "llama-3.3-70b-versatile"
    @AppStorage("deepseekTranslationModel") private var deepseekModel: String = "deepseek-chat"
    @AppStorage("googleTranslationModel") private var googleModel: String = "gemini-3-flash-preview"
    
    @AppStorage("translationTargetLanguage") private var targetLanguage: String = "en"
    
    @AppStorage("ollamaTranslationBaseURL") private var ollamaBaseURL: String = "http://localhost:11434/v1/chat/completions"
    @AppStorage("ollamaTranslationModel") private var ollamaModel: String = "llama3"
    
    @AppStorage("customTranslationBaseURL") private var customBaseURL: String = "https://api.openai.com/v1/chat/completions"
    @AppStorage("customTranslationApiKey") private var customApiKey: String = ""
    @AppStorage("customTranslationModel") private var customModel: String = "gpt-4"
    
    @State private var isTestRunning = false
    @State private var testStatus: String?
    @State private var isTestSuccessful: Bool = false
    @State private var localToggleState: Bool = false
    
    var currentProvider: TranslationProvider {
        TranslationProvider(rawValue: translationProviderString) ?? .deepl
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI Translation Service")
                            .font(.title2.weight(.bold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    
                    HStack(spacing: 12) {
                        if isTestRunning && localToggleState {
                            ProgressView()
                                .controlSize(.small)
                        }
                        
                        Toggle("Use AI Translation", isOn: $localToggleState)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .disabled(isTestRunning)
                            .onChange(of: localToggleState) { newValue in
                                if newValue {
                                    // Only verify if we are turning it ON from an OFF state
                                    // This prevents the automatic refresh when visiting the screen
                                    if !useAITranslation {
                                        verifyAndEnable()
                                    }
                                } else {
                                    useAITranslation = false
                                }
                            }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "character.book.closed.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                    Text("Translation Provider")
                        .font(.body)
                        .foregroundColor(.white)
                    Spacer()
                    Picker("Provider", selection: $translationProviderString) {
                        ForEach(TranslationProvider.allCases) { provider in
                            Text(provider.rawValue).tag(provider.rawValue)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 250)
                    .onChange(of: translationProviderString) { _ in
                        isTestSuccessful = false
                        testStatus = nil
                        if localToggleState {
                            localToggleState = false
                        }
                    }
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "globe")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                    Text("Target Language")
                        .font(.body)
                        .foregroundColor(.white)
                    Spacer()
                    SearchableLanguagePicker(selection: $targetLanguage, languages: TranscriptionLanguage.all)
                        .frame(width: 250)
                }
                
                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.vertical, 8)
                
                // Show selected provider config
                switch currentProvider {
                case .apple:
                    appleTranslationView()
                case .deepl:
                    providerConfigView(title: "DeepL API Key", icon: "doc.text.fill", color: .cyan, value: $deeplApiKey, placeholder: "API Key (free or pro)")
                case .openai:
                    llmConfigView(title: "OpenAI API Key", icon: "cube.fill", color: .green, value: $openAIApiKey, placeholder: "sk-proj-...", modelBinding: $openaiModel, availableModels: ["gpt-4o", "gpt-4o-mini", "gpt-4-turbo", "o1-mini", "o3-mini"])
                case .anthropic:
                    llmConfigView(title: "Anthropic API Key", icon: "brain.head.profile", color: .orange, value: $anthropicApiKey, placeholder: "sk-ant-...", modelBinding: $anthropicModel, availableModels: [
                        // Claude 4.x (2026 latest)
                        "claude-opus-4-6-20260205", "claude-sonnet-4-6-20260217", "claude-haiku-4-5-20251015",
                        // Claude 4 (2025)
                        "claude-opus-4-5-20251101", "claude-sonnet-4-5-20250922", "claude-sonnet-4-20250522",
                        // Claude 3.7
                        "claude-sonnet-3-7-20250219",
                        // Claude 3.5
                        "claude-3-5-sonnet-latest", "claude-3-5-haiku-latest",
                        // Claude 3 (legacy)
                        "claude-3-opus-20240229", "claude-3-haiku-20240307"
                    ])
                case .groq:
                    llmConfigView(title: "Groq API Key", icon: "bolt.fill", color: .red, value: $groqApiKey, placeholder: "gsk_...", modelBinding: $groqModel, availableModels: ["llama-3.3-70b-versatile", "llama-3.1-70b-versatile", "llama3-70b-8192"])
                case .deepseek:
                    llmConfigView(title: "Deepseek API Key", icon: "magnifyingglass", color: .blue, value: $deepseekApiKey, placeholder: "sk-...", modelBinding: $deepseekModel, availableModels: ["deepseek-chat", "deepseek-reasoner"])
                case .google:
                    llmConfigView(title: "Google Gemini API Key", icon: "sparkles.rectangle.stack.fill", color: .blue, value: $googleApiKey, placeholder: "AIza...", modelBinding: $googleModel, availableModels: [
                        "gemini-3.1-pro-preview",
                        "gemini-3.1-flash-lite-preview",
                        "gemini-3-pro-preview",
                        "gemini-3-flash-preview",
                        "gemini-2.5-pro",
                        "gemini-2.5-flash",
                        "gemini-2.5-flash-lite",
                        "gemini-2.0-flash",
                        "gemini-2.0-flash-lite",
                        "gemini-pro-latest"
                    ])
                case .ollama:
                    ollamaConfigView()
                case .custom:
                    customProviderConfigView()
                }
                
                // Test Button
                if currentProvider != .apple {
                    HStack(spacing: 12) {
                        if let url = getAPIKeyURL(for: currentProvider) {
                            Button(action: {
                                if let nsUrl = URL(string: url) {
                                    NSWorkspace.shared.open(nsUrl)
                                }
                            }) {
                                Text("Get Free Key")
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.white.opacity(0.1))
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Button(action: {
                            Task {
                                await executeTest()
                            }
                        }) {
                            HStack {
                                if isTestRunning && !localToggleState {
                                    ProgressView().controlSize(.small)
                                }
                                Text(isTestRunning && !localToggleState ? "Testing..." : "Verify Connection")
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(ThemeColors.accent)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .disabled(isTestRunning)
                        
                        if let status = testStatus {
                            HStack(spacing: 6) {
                                Image(systemName: isTestSuccessful ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .foregroundColor(isTestSuccessful ? .green : .red)
                                
                                Text(status)
                                    .font(.caption)
                                    .foregroundColor(isTestSuccessful ? .green : .red)
                            }
                            .padding(.leading, 8)
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .onAppear {
            localToggleState = useAITranslation
        }
    }
    
    private func fetchLatestModels(for provider: TranslationProvider) {
        let key: String
        let baseUrl: String
        let cacheKey: String
        
        switch provider {
        case .google:
            key = googleApiKey
            baseUrl = ""
            cacheKey = "google"
        case .openai:
            key = openAIApiKey
            baseUrl = ""
            cacheKey = "openai"
        case .anthropic:
            key = anthropicApiKey
            baseUrl = ""
            cacheKey = "anthropic"
        case .groq:
            key = groqApiKey
            baseUrl = "https://api.groq.com/openai/v1/chat/completions"
            cacheKey = "groq"
        case .deepseek:
            key = deepseekApiKey
            baseUrl = "https://api.deepseek.com/chat/completions"
            cacheKey = "deepseek"
        case .ollama:
            key = ""
            baseUrl = ollamaBaseURL
            cacheKey = "ollama"
        default: return
        }
        
        if key.isEmpty && provider != .ollama {
            testStatus = "Please enter an API key first."
            return
        }
        
        Task {
            do {
                let fetched: [String]
                switch provider {
                case .google:
                    fetched = try await GeminiManager.shared.fetchAvailableModels(apiKey: key)
                case .openai:
                    fetched = try await OpenAIManager.shared.fetchAvailableModels(apiKey: key)
                case .anthropic:
                    fetched = try await AnthropicManager.shared.fetchAvailableModels(apiKey: key)
                default:
                    // Map TranslationProvider to LLMProvider for the generic fetch
                    let llmProv: LLMProvider = (provider == .groq) ? .groq : (provider == .deepseek ? .deepseek : .ollama)
                    fetched = try await ExtendedLLMManager.shared.fetchAvailableModels(apiKey: key, baseURL: baseUrl, provider: llmProv)
                }
                
                DispatchQueue.main.async {
                    ModelCacheManager.shared.saveModels(fetched, for: cacheKey)
                    testStatus = "Fetched \(fetched.count) models"
                    isTestSuccessful = true
                }
            } catch {
                DispatchQueue.main.async {
                    testStatus = "Fetch failed: \(error.localizedDescription)"
                    isTestSuccessful = false
                }
            }
        }
    }

    @ViewBuilder
    private func appleTranslationView() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Native Apple Translation")
                .font(.body.weight(.medium))
                .foregroundColor(.white)
            Text("Uses on-device framework. Available strictly on macOS 14.1 and newer.")
                .font(.caption)
                .foregroundColor(ThemeColors.secondaryText)
        }
    }
    
    @ViewBuilder
    private func providerConfigView(title: String, icon: String, color: Color, value: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 24, height: 24)
                    .background(color.opacity(0.2))
                    .cornerRadius(6)
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundColor(.white)
            }
            SecureField(placeholder, text: value)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
    
    @ViewBuilder
    private func llmConfigView(title: String, icon: String, color: Color, value: Binding<String>, placeholder: String, modelBinding: Binding<String>, availableModels: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            providerConfigView(title: title, icon: icon, color: color, value: value, placeholder: placeholder)
            HStack {
                Text("Model:")
                    .foregroundColor(.white.opacity(0.8))
                
                let cacheKey: String = {
                    if title.contains("Google") { return "google" }
                    if title.contains("OpenAI") { return "openai" }
                    if title.contains("Anthropic") { return "anthropic" }
                    if title.contains("Groq") { return "groq" }
                    if title.contains("Deepseek") { return "deepseek" }
                    return title.lowercased()
                }()
                
                let provider: TranslationProvider = {
                    if title.contains("Google") { return .google }
                    if title.contains("OpenAI") { return .openai }
                    if title.contains("Anthropic") { return .anthropic }
                    if title.contains("Groq") { return .groq }
                    if title.contains("Deepseek") { return .deepseek }
                    return .openai
                }()

                let combinedModels = ModelCacheManager.shared.mergeModels(
                    predefined: availableModels,
                    fetched: ModelCacheManager.shared.getModels(for: cacheKey)
                )

                Picker("", selection: modelBinding) {
                    ForEach(combinedModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 200)

                Button(action: {
                    fetchLatestModels(for: provider)
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                        .foregroundColor(color)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Refresh model list")
            }
        }
    }
    
    @ViewBuilder
    private func ollamaConfigView() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("URL: ")
                    .foregroundColor(.white.opacity(0.8))
                TextField("http://localhost:11434/v1/chat/completions", text: $ollamaBaseURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            HStack {
                Text("Model:")
                    .foregroundColor(.white.opacity(0.8))
                TextField("E.g. llama3", text: $ollamaModel)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 200)
            }
        }
    }
    
    @ViewBuilder
    private func customProviderConfigView() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Endpoint (/v1/chat/completions)", text: $customBaseURL)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            SecureField("API Key (Optional)", text: $customApiKey)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            HStack {
                Text("Model:")
                    .foregroundColor(.white.opacity(0.8))
                TextField("E.g. gpt-4", text: $customModel)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 200)
            }
        }
    }
    
    private func verifyAndEnable() {
        if currentProvider == .apple {
            self.useAITranslation = true
            self.isTestSuccessful = true
            return
        }
        
        Task {
            let success = await executeTest()
            DispatchQueue.main.async {
                if success {
                    self.useAITranslation = true
                } else {
                    self.localToggleState = false
                    self.useAITranslation = false
                }
            }
        }
    }
    
    private func executeTest() async -> Bool {
        await MainActor.run { isTestRunning = true; testStatus = nil }
        
        var valid = false
        var msg = ""
        
        do {
            switch currentProvider {
            case .apple: valid = true; msg = "Ready"
            case .deepl:
                if deeplApiKey.isEmpty { throw NSError(domain: "Missing Key", code: -1) }
                _ = try await DeepLManager.shared.translate(text: "Hello", targetLanguage: targetLanguage)
                valid = true; msg = "DeepL verified!"
            case .openai:
                if openAIApiKey.isEmpty { throw NSError(domain: "Missing Key", code: -1) }
                _ = try await OpenAIManager.shared.improveText(prompt: "Translate to \(targetLanguage)", text: "Hello", model: openaiModel)
                valid = true; msg = "OpenAI verified!"
            case .anthropic:
                if anthropicApiKey.isEmpty { throw NSError(domain: "Missing Key", code: -1) }
                _ = try await AnthropicManager.shared.improveText(prompt: "Translate to \(targetLanguage)", text: "Hello", model: anthropicModel)
                valid = true; msg = "Anthropic verified!"
            case .google:
                if googleApiKey.isEmpty { throw NSError(domain: "Missing Key", code: -1) }
                _ = try await GeminiManager.shared.improveText(systemPrompt: "Respond 'OK'", userText: "Ping", apiKey: googleApiKey, model: googleModel)
                valid = true; msg = "Google verified!"
            case .groq, .deepseek, .ollama, .custom:
                let extProvider: LLMProvider
                let key: String
                let url: String
                let modelUsed: String
                
                switch currentProvider {
                case .groq:
                    extProvider = .groq; key = groqApiKey; url = "https://api.groq.com/openai/v1/chat/completions"; modelUsed = groqModel
                case .deepseek:
                    extProvider = .deepseek; key = deepseekApiKey; url = "https://api.deepseek.com/chat/completions"; modelUsed = deepseekModel
                case .ollama:
                    extProvider = .ollama; key = ""; url = ollamaBaseURL; modelUsed = ollamaModel
                case .custom:
                    extProvider = .custom; key = customApiKey; url = customBaseURL; modelUsed = customModel
                default: throw NSError(domain: "Invalid map", code: -1)
                }
                
                _ = try await ExtendedLLMManager.shared.improveText(prompt: "Translate to \(targetLanguage)", text: "Hello", provider: extProvider, apiKey: key, baseURL: url, model: modelUsed)
                valid = true; msg = "\(currentProvider.rawValue) verified!"
            }
        } catch {
            msg = "Error: \(error.localizedDescription)"
        }
        
        await MainActor.run {
            self.isTestSuccessful = valid
            self.testStatus = msg
            self.isTestRunning = false
        }
        return valid
    }
    
    private func getAPIKeyURL(for provider: TranslationProvider) -> String? {
        switch provider {
        case .apple: return nil
        case .deepl: return "https://www.deepl.com/pro-api"
        case .openai: return "https://platform.openai.com/api-keys"
        case .anthropic: return "https://console.anthropic.com/settings/keys"
        case .groq: return "https://console.groq.com/keys"
        case .deepseek: return "https://platform.deepseek.com/api_keys"
        case .google: return "https://aistudio.google.com/app/apikey"
        case .ollama, .custom: return nil
        }
    }
}
