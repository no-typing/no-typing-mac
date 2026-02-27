import SwiftUI

struct ExtendedLLMSettingsView: View {
    @AppStorage("extendedLLMProvider") private var selectedProvider: String = LLMProvider.groq.rawValue
    
    // Groq
    @AppStorage("groqApiKey") private var groqApiKey: String = ""
    @AppStorage("groqModel") private var groqModel: String = "llama3-70b-8192"
    
    // Deepseek
    @AppStorage("deepseekApiKey") private var deepseekApiKey: String = ""
    @AppStorage("deepseekModel") private var deepseekModel: String = "deepseek-chat"
    
    // Ollama
    @AppStorage("ollamaBaseURL") private var ollamaBaseURL: String = "http://localhost:11434/v1/chat/completions"
    @AppStorage("ollamaModel") private var ollamaModel: String = "llama3"
    
    // Custom
    @AppStorage("customLLMBaseURL") private var customBaseURL: String = "https://api.openai.com/v1/chat/completions"
    @AppStorage("customLLMApiKey") private var customApiKey: String = ""
    @AppStorage("customLLMModel") private var customModel: String = "gpt-4"
    
    @State private var isTestRunning = false
    @State private var testStatus: String?
    @State private var isTestSuccessful: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Extended LLM Integration")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Use alternative models for text rewriting, like Groq, Deepseek, Ollama, or Custom API endpoints.")
                    .font(.subheadline)
                    .foregroundColor(ThemeColors.secondaryText)
            }
            
            Picker("Provider", selection: $selectedProvider) {
                ForEach(LLMProvider.allCases) { provider in
                    Text(provider.rawValue).tag(provider.rawValue)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.vertical, 8)
            
            if selectedProvider == LLMProvider.groq.rawValue {
                buildGroqUI()
            } else if selectedProvider == LLMProvider.deepseek.rawValue {
                buildDeepseekUI()
            } else if selectedProvider == LLMProvider.ollama.rawValue {
                buildOllamaUI()
            } else {
                buildCustomUI()
            }
            
            if let status = testStatus {
                HStack(spacing: 6) {
                    Image(systemName: isTestSuccessful ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(isTestSuccessful ? .green : .red)
                    
                    Text(status)
                        .font(.caption)
                        .foregroundColor(isTestSuccessful ? .green : .red)
                }
                .transition(.opacity)
            }
        }
        .padding(20)
    }
    
    @ViewBuilder
    private func buildGroqUI() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SecureField("Groq API Key (gsk_...)", text: $groqApiKey)
                .textFieldStyle(PlainTextFieldStyle())
                .padding()
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
            
            HStack {
                Text("Model:")
                    .foregroundColor(.white.opacity(0.8))
                TextField("E.g. llama3-70b-8192", text: $groqModel)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 200)
                
                Spacer()
                testButton(apiKey: groqApiKey)
            }
        }
    }
    
    @ViewBuilder
    private func buildDeepseekUI() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SecureField("Deepseek API Key", text: $deepseekApiKey)
                .textFieldStyle(PlainTextFieldStyle())
                .padding()
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
            
            HStack {
                Text("Model:")
                    .foregroundColor(.white.opacity(0.8))
                TextField("E.g. deepseek-chat", text: $deepseekModel)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 200)
                
                Spacer()
                testButton(apiKey: deepseekApiKey)
            }
        }
    }
    
    @ViewBuilder
    private func buildOllamaUI() -> some View {
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
                
                Spacer()
                testButton(apiKey: "local")
            }
        }
    }
    
    @ViewBuilder
    private func buildCustomUI() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("URL: ")
                    .foregroundColor(.white.opacity(0.8))
                TextField("Endpoint (/v1/chat/completions)", text: $customBaseURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            SecureField("API Key (Optional)", text: $customApiKey)
                .textFieldStyle(PlainTextFieldStyle())
                .padding()
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
            
            HStack {
                Text("Model:")
                    .foregroundColor(.white.opacity(0.8))
                TextField("E.g. my-custom-model", text: $customModel)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 200)
                
                Spacer()
                testButton(apiKey: customApiKey.isEmpty ? "empty" : customApiKey)
            }
        }
    }
    
    private func testButton(apiKey: String) -> some View {
        Button(action: {
            testAPI()
        }) {
            HStack {
                if isTestRunning {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(isTestRunning ? "Testing..." : "Test Connection")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(apiKey.isEmpty ? Color.gray.opacity(0.3) : ThemeColors.accent)
            .foregroundColor(apiKey.isEmpty ? .gray : .white)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(apiKey.isEmpty || isTestRunning)
    }
    
    private func testAPI() {
        isTestRunning = true
        testStatus = nil
        
        let provider = LLMProvider(rawValue: selectedProvider) ?? .custom
        let key: String
        let url: String
        let modelStr: String
        
        switch provider {
        case .groq:
            key = groqApiKey
            url = "https://api.groq.com/openai/v1/chat/completions"
            modelStr = groqModel
        case .deepseek:
            key = deepseekApiKey
            url = "https://api.deepseek.com/chat/completions"
            modelStr = deepseekModel
        case .ollama:
            key = ""
            url = ollamaBaseURL
            modelStr = ollamaModel
        case .custom:
            key = customApiKey
            url = customBaseURL
            modelStr = customModel
        }
        
        Task {
            do {
                _ = try await ExtendedLLMManager.shared.improveText(
                    prompt: "You are a helpful assistant. Respond exactly with 'OK'.",
                    text: "Ping",
                    provider: provider,
                    apiKey: key,
                    baseURL: url,
                    model: modelStr
                )
                DispatchQueue.main.async {
                    self.isTestSuccessful = true
                    self.testStatus = "Connection successful!"
                    self.isTestRunning = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.isTestSuccessful = false
                    self.testStatus = error.localizedDescription
                    self.isTestRunning = false
                }
            }
        }
    }
}
