import SwiftUI

struct OpenAISettingsView: View {
    @AppStorage("openaiApiKey") private var openaiApiKey: String = ""
    @AppStorage("openaiModelSelection") private var openaiModelSelection: String = OpenAIModel.gpt4o.rawValue
    
    @State private var isTestRunning = false
    @State private var testStatus: String?
    @State private var isTestSuccessful: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            VStack(alignment: .leading, spacing: 8) {
                Text("OpenAI (ChatGPT) API Key")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Insert your OpenAI API key to unlock dynamic grammar dictation and rewriting capabilities. You can generate one at platform.openai.com.")
                    .font(.subheadline)
                    .foregroundColor(ThemeColors.secondaryText)
            }
            
            HStack(spacing: 12) {
                SecureField("sk-...", text: $openaiApiKey)
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
                    .background(openaiApiKey.isEmpty ? Color.gray.opacity(0.3) : ThemeColors.accent)
                    .foregroundColor(openaiApiKey.isEmpty ? .gray : .white)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(openaiApiKey.isEmpty || isTestRunning)
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
