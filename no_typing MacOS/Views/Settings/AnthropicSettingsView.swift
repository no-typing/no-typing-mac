import SwiftUI

struct AnthropicSettingsView: View {
    @AppStorage("anthropicApiKey") private var anthropicApiKey: String = ""
    @AppStorage("anthropicModelSelection") private var anthropicModelSelection: String = AnthropicModel.claude35Sonnet.rawValue
    
    @State private var isTestRunning = false
    @State private var testStatus: String?
    @State private var isTestSuccessful: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Anthropic (Claude) API Key")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Insert your Anthropic API key to utilize Claude for grammar dictation and text refinement. You can generate one at console.anthropic.com.")
                    .font(.subheadline)
                    .foregroundColor(ThemeColors.secondaryText)
            }
            
            HStack(spacing: 12) {
                SecureField("sk-ant-...", text: $anthropicApiKey)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                
                Button(action: {
                    testAPIKey()
                }) {
                    HStack {
                        if isTestRunning {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(isTestRunning ? "Testing..." : "Test Key")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(anthropicApiKey.isEmpty ? Color.gray.opacity(0.3) : ThemeColors.accent)
                    .foregroundColor(anthropicApiKey.isEmpty ? .gray : .white)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(anthropicApiKey.isEmpty || isTestRunning)
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
