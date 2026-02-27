import SwiftUI

struct DeepLSettingsView: View {
    @AppStorage("deeplApiKey") private var deeplApiKey: String = ""
    @State private var isTestRunning = false
    @State private var testStatus: String?
    @State private var isTestSuccessful: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            VStack(alignment: .leading, spacing: 8) {
                Text("DeepL API Key")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Insert your DeepL Developer API key to unlock full transcript translation. Both Free and Pro keys are supported.")
                    .font(.subheadline)
                    .foregroundColor(ThemeColors.secondaryText)
            }
            
            HStack(spacing: 12) {
                SecureField("Enter DeepL Auth Key (e.g. ...:fx)", text: $deeplApiKey)
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
                    .background(deeplApiKey.isEmpty ? Color.gray.opacity(0.3) : ThemeColors.accent)
                    .foregroundColor(deeplApiKey.isEmpty ? .gray : .white)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(deeplApiKey.isEmpty || isTestRunning)
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
                _ = try await DeepLManager.shared.translate(text: "Hello", targetLanguage: "DE")
                DispatchQueue.main.async {
                    self.isTestSuccessful = true
                    self.testStatus = "API Key is valid!"
                    self.isTestRunning = false
                }
            } catch let error as DeepLError {
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
