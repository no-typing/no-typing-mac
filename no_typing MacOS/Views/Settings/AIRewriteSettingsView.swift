import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

enum RewriteProvider: String, CaseIterable, Identifiable {
    case appleIntelligence = "Apple Intelligence"
    case openai = "OpenAI"
    case anthropic = "Anthropic"
    case groq = "Groq"
    case deepseek = "Deepseek"
    case google = "Google"
    case ollama = "Ollama"
    case custom = "Custom API endpoint"
    
    var id: String { self.rawValue }
}

struct AIRewriteSettingsView: View {
    @AppStorage("enableTranscriptionCleaning") private var useAIRewrite: Bool = true
    @AppStorage("aiRewriteProvider") private var rewriteProviderString: String = RewriteProvider.appleIntelligence.rawValue
    
    // API Keys (re-using existing standard keys if possible, or keeping them separate if user prefers?)
    // ExtendedLLMSettingsView uses these:
    @AppStorage("openaiApiKey") private var openAIApiKey: String = ""
    @AppStorage("anthropicApiKey") private var anthropicApiKey: String = ""
    @AppStorage("groqApiKey") private var groqApiKey: String = ""
    @AppStorage("deepseekApiKey") private var deepseekApiKey: String = ""
    
    // Models
    @AppStorage("openaiModelSelection") private var openaiModel: String = "gpt-4o"
    @AppStorage("anthropicModelSelection") private var anthropicModel: String = "claude-3-5-sonnet-latest"
    @AppStorage("groqModel") private var groqModel: String = "llama3-70b-8192"
    @AppStorage("deepseekModel") private var deepseekModel: String = "deepseek-chat"
    @AppStorage("googleApiKey") private var googleApiKey: String = ""
    @AppStorage("googleModel") private var googleModel: String = "gemini-2.0-flash"
    
    @AppStorage("ollamaBaseURL") private var ollamaBaseURL: String = "http://localhost:11434/v1/chat/completions"
    @AppStorage("ollamaModel") private var ollamaModel: String = "llama3"
    
    @AppStorage("customLLMBaseURL") private var customBaseURL: String = "https://api.openai.com/v1/chat/completions"
    @AppStorage("customLLMApiKey") private var customApiKey: String = ""
    @AppStorage("customLLMModel") private var customModel: String = "gpt-4"
    
    @State private var isTestRunning = false
    @State private var testStatus: String?
    @State private var isTestSuccessful: Bool = false
    @State private var localToggleState: Bool = false
    
    var currentProvider: RewriteProvider {
        RewriteProvider(rawValue: rewriteProviderString) ?? .appleIntelligence
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI Rewrite Service")
                            .font(.title2.weight(.bold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    
                    HStack(spacing: 12) {
                        if isTestRunning && localToggleState {
                            ProgressView()
                                .controlSize(.small)
                        }
                        
                        Toggle("Use AI Rewrite", isOn: $localToggleState)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .disabled(isTestRunning)
                            .onChange(of: localToggleState) { newValue in
                                if newValue {
                                    verifyAndEnable()
                                } else {
                                    useAIRewrite = false
                                }
                            }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundColor(.purple)
                    Text("Service Provider")
                        .font(.body)
                        .foregroundColor(.white)
                    Spacer()
                    Picker("Provider", selection: $rewriteProviderString) {
                        ForEach(RewriteProvider.allCases) { provider in
                            Text(provider.rawValue).tag(provider.rawValue)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 250)
                    .onChange(of: rewriteProviderString) { _ in
                        isTestSuccessful = false
                        testStatus = nil
                        if localToggleState {
                            localToggleState = false
                        }
                    }
                }
                
                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.vertical, 8)
                
                // Show only the selected provider's settings
                switch currentProvider {
                case .appleIntelligence:
                    appleIntelligenceView()
                case .openai:
                    providerConfigView(title: "OpenAI API Key", icon: "cube.fill", color: .green, value: $openAIApiKey, placeholder: "sk-proj-...", modelBinding: $openaiModel, availableModels: [
                        // GPT-5 series
                        "gpt-5.4-pro", "gpt-5.4", "gpt-5.4-mini", "gpt-5.4-nano", "gpt-5.4-thinking",
                        "gpt-5.3", "gpt-5.3-instant", "gpt-5.3-codex",
                        "gpt-5.2", "gpt-5.2-thinking",
                        "gpt-5.1",
                        "gpt-5", "gpt-5-thinking",
                        // OSS
                        "gpt-oss-120b", "gpt-oss-20b",
                        // o-series (reasoning)
                        "o4-mini", "o3-pro", "o3", "o3-mini-high", "o3-mini",
                        "o1-pro", "o1", "o1-mini",
                        // GPT-4.1 series
                        "gpt-4.1", "gpt-4.1-mini", "gpt-4.1-nano",
                        // GPT-4o series
                        "gpt-4o", "gpt-4o-mini",
                        // GPT-4.5
                        "gpt-4.5-preview",
                        // GPT-4 classic
                        "gpt-4-turbo", "gpt-4",
                        // GPT-3.5
                        "gpt-3.5-turbo"
                    ])
                case .anthropic:
                    providerConfigView(title: "Anthropic API Key", icon: "brain.head.profile", color: .orange, value: $anthropicApiKey, placeholder: "sk-ant-...", modelBinding: $anthropicModel, availableModels: [
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
                    providerConfigView(title: "Groq API Key", icon: "bolt.fill", color: .red, value: $groqApiKey, placeholder: "gsk_...", modelBinding: $groqModel, availableModels: [
                        // Llama 4
                        "llama-4-scout", "llama-4-maverick", "llama-4-guard-12b",
                        // Llama 3.3
                        "llama-3.3-70b-versatile",
                        // Llama 3.1
                        "llama-3.1-70b-versatile", "llama-3.1-8b-instant",
                        // Llama 3 classic
                        "llama3-70b-8192", "llama3-8b-8192",
                        // Qwen
                        "qwen-qwq-32b", "qwen3-32b", "qwen3.5-27b", "qwen3.5-9b",
                        // Mistral
                        "mixtral-8x7b-32768", "mistral-saba-24b",
                        // Gemma
                        "gemma2-9b-it", "gemma-3-27b", "gemma-3-12b", "gemma-3-4b",
                        // Kimi
                        "moonshotai/kimi-k2", "moonshotai/kimi-k2-instruct-0905", "moonshotai/kimi-k2.5",
                        // OpenAI OSS via Groq
                        "openai/gpt-oss-120b", "openai/gpt-oss-20b", "openai/gpt-oss-safeguard-20b",
                        // DeepSeek via Groq
                        "deepseek-r1-distill-llama-70b", "deepseek-r1-distill-qwen-32b", "deepseek-v3.2"
                    ])
                case .deepseek:
                    providerConfigView(title: "Deepseek API Key", icon: "magnifyingglass", color: .blue, value: $deepseekApiKey, placeholder: "sk-...", modelBinding: $deepseekModel, availableModels: [
                        // V4 series (newest)
                        "deepseek-v4", "deepseek-v4-pro", "deepseek-v4-lite",
                        // V3 series
                        "deepseek-v3.2-speciale", "deepseek-v3.2", "deepseek-v3.1",
                        "deepseek-chat",       // alias for V3
                        // R-series (reasoning)
                        "deepseek-r2-pro", "deepseek-r2",
                        "deepseek-reasoner",   // alias for R1
                        // Coder
                        "deepseek-coder-v3", "deepseek-coder-v2.5",
                        // Multimodal & Math
                        "deepseek-vl2", "deepseek-math-v2"
                    ])
                case .google:
                    providerConfigView(title: "Google Gemini API Key", icon: "sparkles.rectangle.stack.fill", color: .blue, value: $googleApiKey, placeholder: "AIza...", modelBinding: $googleModel, availableModels: [
                        // Gemini 3.1
                        "gemini-3.1-pro", "gemini-3.1-flash", "gemini-3.1-flash-lite",
                        // Gemini 3
                        "gemini-3-pro", "gemini-3-flash",
                        // Gemini 2.5
                        "gemini-2.5-pro", "gemini-2.5-flash"
                    ])
                case .ollama:
                    ollamaConfigView()
                case .custom:
                    customProviderConfigView()
                }
                
                // Test Button
                if currentProvider != .appleIntelligence {
                    HStack {
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
            localToggleState = useAIRewrite
        }
    }
    
    @ViewBuilder
    private func appleIntelligenceView() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "applelogo")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(6)
                
                Text("Apple Intelligence")
                    .font(.body.weight(.medium))
                    .foregroundColor(.white)
            }
            
            Text("Uses on-device native ML. Available strictly on macOS 15.1 and newer.")
                .font(.caption)
                .foregroundColor(ThemeColors.secondaryText)
                
            if #available(macOS 15.1, *) {
                #if canImport(FoundationModels)
                Text("✅ Ready and available on your system.")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                    .padding(.top, 4)
                #else
                Text("❌ Xcode does not support FoundationModels in this build.")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                    .padding(.top, 4)
                #endif
            } else {
                Text("❌ Not available. Requires macOS 15.1 or higher.")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                    .padding(.top, 4)
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
    private func providerConfigView(title: String, icon: String, color: Color, value: Binding<String>, placeholder: String, modelBinding: Binding<String>, availableModels: [String]) -> some View {
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
                
            HStack {
                Text("Model:")
                    .foregroundColor(.white.opacity(0.8))
                Picker("", selection: modelBinding) {
                    ForEach(availableModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 200)
            }
        }
    }
    
    @ViewBuilder
    private func customProviderConfigView() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "server.rack")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.gray)
                    .frame(width: 24, height: 24)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(6)
                
                Text("Custom Local/Remote Server")
                    .font(.body.weight(.medium))
                    .foregroundColor(.white)
            }
            
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
        if currentProvider == .appleIntelligence {
            if #available(macOS 15.1, *) {
                #if canImport(FoundationModels)
                self.useAIRewrite = true
                self.isTestSuccessful = true
                #else
                self.localToggleState = false
                self.useAIRewrite = false
                self.testStatus = "FoundationModels not supported in build"
                #endif
            } else {
                self.localToggleState = false
                self.useAIRewrite = false
                self.testStatus = "Requires macOS 15.1"
            }
            return
        }
        
        Task {
            let success = await executeTest()
            DispatchQueue.main.async {
                if success {
                    self.useAIRewrite = true
                } else {
                    self.localToggleState = false
                    self.useAIRewrite = false
                }
            }
        }
    }
    
    private func executeTest() async -> Bool {
        await MainActor.run {
            isTestRunning = true
            testStatus = nil
        }
        
        let valid: Bool
        let statusText: String
        do {
            switch currentProvider {
            case .appleIntelligence:
                valid = true
                statusText = "Ready"
            case .openai:
                if openAIApiKey.isEmpty { throw NSError(domain: "Missing Key", code: -1) }
                _ = try await OpenAIManager.shared.improveText(prompt: "Respond 'OK'", text: "Ping", model: openaiModel)
                valid = true
                statusText = "OpenAI verified!"
            case .anthropic:
                if anthropicApiKey.isEmpty { throw NSError(domain: "Missing Key", code: -1) }
                _ = try await AnthropicManager.shared.improveText(prompt: "Respond 'OK'", text: "Ping", model: anthropicModel)
                valid = true
                statusText = "Anthropic verified!"
            case .groq, .deepseek, .ollama, .custom:
                let extProvider: LLMProvider
                let key: String
                let url: String
                let modelUsed: String
                
                switch currentProvider {
                case .groq:
                    extProvider = .groq
                    key = groqApiKey
                    url = "https://api.groq.com/openai/v1/chat/completions"
                    modelUsed = groqModel
                case .deepseek:
                    extProvider = .deepseek
                    key = deepseekApiKey
                    url = "https://api.deepseek.com/chat/completions"
                    modelUsed = deepseekModel
                case .ollama:
                    extProvider = .ollama
                    key = ""
                    url = ollamaBaseURL
                    modelUsed = ollamaModel
                case .custom:
                    extProvider = .custom
                    key = customApiKey
                    url = customBaseURL
                    modelUsed = customModel
                default: 
                    throw NSError(domain: "Invalid map", code: -1)
                }
                
                if (extProvider == .groq || extProvider == .deepseek) && key.isEmpty {
                    throw NSError(domain: "Missing API Key", code: -1)
                }
                
                _ = try await ExtendedLLMManager.shared.improveText(prompt: "Respond 'OK'", text: "Ping", provider: extProvider, apiKey: key, baseURL: url, model: modelUsed)
                valid = true
                statusText = "\(currentProvider.rawValue) verified!"
            case .google:
                if googleApiKey.isEmpty { throw NSError(domain: "Missing Key", code: -1) }
                let url = "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"
                _ = try await ExtendedLLMManager.shared.improveText(prompt: "Respond 'OK'", text: "Ping", provider: .google, apiKey: googleApiKey, baseURL: url, model: googleModel)
                valid = true
                statusText = "Google Gemini verified!"
            }
            
            await MainActor.run {
                self.isTestSuccessful = valid
                self.testStatus = statusText
                self.isTestRunning = false
            }
            return valid
        } catch {
            await MainActor.run {
                self.isTestSuccessful = false
                self.testStatus = "Error: \(error.localizedDescription)"
                self.isTestRunning = false
            }
            return false
        }
    }
}
