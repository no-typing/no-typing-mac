import SwiftUI

struct WebhookSettingsView: View {
    @AppStorage("webhookEnabled") private var webhookEnabled: Bool = false
    @AppStorage("webhookURL") private var webhookURL: String = ""
    
    @State private var isTestRunning = false
    @State private var testStatus: String?
    @State private var isTestSuccessful: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text("Integrations & Webhooks")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Toggle("", isOn: $webhookEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: ThemeColors.accent))
                        .labelsHidden()
                }
                
                Text("Automatically forward completed transcripts as JSON payloads to Zapier, Make.com, n8n, Notion webhooks or any custom endpoint.")
                    .font(.subheadline)
                    .foregroundColor(ThemeColors.secondaryText)
            }
            
            if webhookEnabled {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("POST URL:")
                            .foregroundColor(.white.opacity(0.8))
                        TextField("https://hooks.zapier.com/...", text: $webhookURL)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    HStack {
                        Spacer()
                        testButton()
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
                .padding(.top, 4)
            }
        }
        .padding(20)
    }
    
    private func testButton() -> some View {
        Button(action: {
            testAPI()
        }) {
            HStack {
                if isTestRunning {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(isTestRunning ? "Testing..." : "Send Test Payload")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(webhookURL.isEmpty ? Color.gray.opacity(0.3) : ThemeColors.accent)
            .foregroundColor(webhookURL.isEmpty ? .gray : .white)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(webhookURL.isEmpty || !webhookURL.lowercased().hasPrefix("http") || isTestRunning)
    }
    
    private func testAPI() {
        guard !webhookURL.isEmpty else { return }
        
        isTestRunning = true
        testStatus = nil
        
        Task {
            do {
                _ = try await WebhookManager.shared.testWebhook(url: webhookURL)
                DispatchQueue.main.async {
                    self.isTestSuccessful = true
                    self.testStatus = "Webhook trigger successful!"
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
