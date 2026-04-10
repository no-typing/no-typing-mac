import SwiftUI

struct CloudTranscriptionSettingsView: View {
    @AppStorage("cloudTranscriptionEnabled") private var useCloudEngine: Bool = false
    @AppStorage("cloudTranscriptionProvider") private var cloudProviderString: String = CloudTranscriptionProvider.deepgram.rawValue
    
    @AppStorage("cloudOpenAIApiKey") private var openAIApiKey: String = ""
    @AppStorage("cloudOpenAIModel") private var openAIModel: String = "whisper-1"
    
    @AppStorage("cloudElevenLabsApiKey") private var elevenLabsApiKey: String = ""
    @AppStorage("cloudElevenLabsModel") private var elevenLabsModel: String = "scribe_v1"
    
    @AppStorage("cloudDeepgramApiKey") private var deepgramApiKey: String = ""
    @AppStorage("cloudDeepgramModel") private var deepgramModel: String = "nova-2"
    
    @AppStorage("cloudGroqApiKey") private var groqApiKey: String = ""
    @AppStorage("cloudGroqModel") private var groqModel: String = "whisper-large-v3-turbo"
    
    @AppStorage("cloudCustomURL") private var customURL: String = ""
    @AppStorage("cloudCustomApiKey") private var customApiKey: String = ""
    @AppStorage("cloudCustomModel") private var customModel: String = "whisper-1"
    
    @State private var isTestRunning = false
    @State private var testStatus: String?
    @State private var isTestSuccessful: Bool = false
    
    @State private var localToggleState: Bool = false
    
    var currentProvider: CloudTranscriptionProvider {
        CloudTranscriptionProvider(rawValue: cloudProviderString) ?? .deepgram
    }
    
    var currentProviderKey: String {
        switch currentProvider {
        case .openai: return openAIApiKey
        case .deepgram: return deepgramApiKey
        case .elevenlabs: return elevenLabsApiKey
        case .groq: return groqApiKey
        case .custom: return customURL
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cloud Models")
                            .font(.title2.weight(.bold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    
                    HStack(spacing: 12) {
                        if isTestRunning && localToggleState {
                            ProgressView()
                                .controlSize(.small)
                        }
                        
                        Toggle("Use Cloud Models", isOn: $localToggleState)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .disabled(isTestRunning)
                            .onChange(of: localToggleState) { newValue in
                                if newValue {
                                    // Only verify if we are turning it ON from an OFF state
                                    // This prevents the automatic refresh when visiting the screen
                                    if !useCloudEngine {
                                        verifyAndEnable()
                                    }
                                } else {
                                    useCloudEngine = false
                                }
                            }
                    }
                }
                HStack(spacing: 10) {
                                Image(systemName: "cloud")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Recommended for slow devices")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.orange)
                                    Text("Cloud models send audio to the internet for processing.")
                                        .font(.system(size: 11))
                                        .foregroundColor(.orange.opacity(0.8))
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.orange.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.orange.opacity(0.25), lineWidth: 1)
                            )
                            .cornerRadius(10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 16) {

                HStack(spacing: 8) {
                    Image(systemName: "cloud")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                    Text("Service Provider")
                        .font(.body)
                        .foregroundColor(.white)
                    Spacer()
                    Picker("Provider", selection: $cloudProviderString) {
                        ForEach(CloudTranscriptionProvider.allCases) { provider in
                            Text(provider.rawValue).tag(provider.rawValue)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 250)
                    .onChange(of: cloudProviderString) { _ in
                        isTestSuccessful = false
                        testStatus = nil
                        if localToggleState {
                            localToggleState = false // turn off if changing provider
                        }
                    }
                }
                
                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.vertical, 8)
                
                // Show only the selected provider's settings
                switch currentProvider {
                case .openai:
                    providerConfigView(title: "OpenAI API Key", icon: "sparkles", color: .purple, value: $openAIApiKey, placeholder: "sk-proj-...", modelBinding: $openAIModel, availableModels: ["whisper-1"])
                case .deepgram:
                    providerConfigView(title: "Deepgram API Key", icon: "waveform", color: .cyan, value: $deepgramApiKey, placeholder: "Token...", modelBinding: $deepgramModel, availableModels: ["nova-2", "nova", "base"])
                case .elevenlabs:
                    providerConfigView(title: "ElevenLabs API Key", icon: "mic.fill", color: .orange, value: $elevenLabsApiKey, placeholder: "sk_...", modelBinding: $elevenLabsModel, availableModels: ["scribe_v1"])
                case .groq:
                    providerConfigView(title: "Groq API Key", icon: "bolt.fill", color: .red, value: $groqApiKey, placeholder: "gsk_...", modelBinding: $groqModel, availableModels: ["whisper-large-v3-turbo", "whisper-large-v3", "distil-whisper-large-v3-en"])
                case .custom:
                    customProviderConfigView()
                }
                
                // Action Buttons
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
                            Text(isTestRunning && !localToggleState ? "Testing Connection..." : "Verify Connection")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(currentProviderKey.isEmpty ? Color.gray.opacity(0.3) : ThemeColors.accent)
                        .foregroundColor(currentProviderKey.isEmpty ? .gray : .white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(currentProviderKey.isEmpty || isTestRunning)
                    
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
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .onAppear {
            localToggleState = useCloudEngine
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
            
            TextField("https://localhost:8080/v1/audio/transcriptions", text: $customURL)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            SecureField("Bearer Token (Optional)", text: $customApiKey)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                
            HStack {
                Text("Model:")
                    .foregroundColor(.white.opacity(0.8))
                TextField("E.g. whisper-1", text: $customModel)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 200)
            }
        }
    }
    
    private func verifyAndEnable() {
        if currentProviderKey.isEmpty {
            localToggleState = false
            testStatus = "API Key cannot be empty"
            isTestSuccessful = false
            return
        }
        
        Task {
            let success = await executeTest()
            DispatchQueue.main.async {
                if success {
                    self.useCloudEngine = true
                } else {
                    self.localToggleState = false
                    self.useCloudEngine = false
                }
            }
        }
    }
    
    private func executeTest() async -> Bool {
        await MainActor.run {
            isTestRunning = true
            testStatus = nil
        }
        
        do {
            let valid = try await CloudTranscriptionManager.shared.testConnection(
                for: currentProvider,
                apiKey: currentProviderKey,
                customURL: customURL
            )
            
            await MainActor.run {
                self.isTestSuccessful = valid
                self.testStatus = valid ? "Connection Successful!" : "Connection Failed. Invalid Key."
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
    
    private func getAPIKeyURL(for provider: CloudTranscriptionProvider) -> String? {
        switch provider {
        case .openai: return "https://platform.openai.com/api-keys"
        case .deepgram: return "https://console.deepgram.com/signup"
        case .elevenlabs: return "https://elevenlabs.io/"
        case .groq: return "https://console.groq.com/keys"
        case .custom: return nil
        }
    }
}
