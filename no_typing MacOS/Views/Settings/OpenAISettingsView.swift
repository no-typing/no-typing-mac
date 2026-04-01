import SwiftUI

struct OpenAISettingsView: View {
    @AppStorage("openaiApiKey") private var openaiApiKey: String = ""
    @AppStorage("openaiModelSelection") private var openaiModelSelection: String = OpenAIModel.gpt4o.rawValue
    
    @State private var isTestRunning = false
    @State private var testStatus: String?
    @State private var isTestSuccessful: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(
                title: "OpenAI (ChatGPT) API Key",
                description: "Insert your OpenAI API key to unlock dynamic grammar dictation and rewriting capabilities. You can generate one at platform.openai.com."
            )
            
            HStack(spacing: 12) {
                CustomSecureField(placeholder: "sk-...", text: $openaiApiKey)
                
                PrimaryButton(
                    title: "Test Key",
                    loadingTitle: "Testing...",
                    isLoading: isTestRunning,
                    isDisabled: openaiApiKey.isEmpty,
                    action: testAPIKey
                )
            }
            
            if !openaiApiKey.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Model Selection")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Picker("", selection: $openaiModelSelection) {
                        ForEach(OpenAIModel.allCases) { model in
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
                _ = try await OpenAIManager.shared.improveText(
                    prompt: "You are a helpful assistant. Respond with exactly the word 'OK'.",
                    text: "Ping",
                    model: "gpt-4o-mini"
                )
                DispatchQueue.main.async {
                    self.isTestSuccessful = true
                    self.testStatus = "API Key is valid!"
                    self.isTestRunning = false
                }
            } catch let error as OpenAIError {
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
