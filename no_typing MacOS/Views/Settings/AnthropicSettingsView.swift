import SwiftUI

struct AnthropicSettingsView: View {
    @AppStorage("anthropicApiKey") private var anthropicApiKey: String = ""
    @AppStorage("anthropicModelSelection") private var anthropicModelSelection: String = AnthropicModel.claude35Sonnet.rawValue
    
    @State private var isTestRunning = false
    @State private var testStatus: String?
    @State private var isTestSuccessful: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(
                title: "Anthropic (Claude) API Key",
                description: "Insert your Anthropic API key to utilize Claude for grammar dictation and text refinement. You can generate one at console.anthropic.com."
            )
            
            HStack(spacing: 12) {
                CustomSecureField(placeholder: "sk-ant-...", text: $anthropicApiKey)
                
                PrimaryButton(
                    title: "Test Key",
                    loadingTitle: "Testing...",
                    isLoading: isTestRunning,
                    isDisabled: anthropicApiKey.isEmpty,
                    action: testAPIKey
                )
            }
            
            if !anthropicApiKey.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Model Selection")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Picker("", selection: $anthropicModelSelection) {
                        ForEach(AnthropicModel.allCases) { model in
                            Text(model.displayName).tag(model.rawValue)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 200)
                }
                .padding(.top, 4)
            }
            
            if let status = testStatus {
                APIKeyStatusView(status: status, isSuccess: isTestSuccessful)
            }
        }
        .padding(20)
    }
    
    private func testAPIKey() {
        isTestRunning = true
        testStatus = nil
        
        Task {
            do {
                _ = try await AnthropicManager.shared.improveText(
                    prompt: "You are a helpful assistant. Respond with exactly the word 'OK'.",
                    text: "Ping",
                    model: "claude-3-haiku-20240307"
                )
                DispatchQueue.main.async {
                    self.isTestSuccessful = true
                    self.testStatus = "API Key is valid!"
                    self.isTestRunning = false
                }
            } catch let error as AnthropicError {
                DispatchQueue.main.async {
                    self.isTestSuccessful = false
                    self.testStatus = error.errorDescription ?? error.localizedDescription
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
