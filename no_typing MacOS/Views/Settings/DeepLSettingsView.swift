import SwiftUI

struct DeepLSettingsView: View {
    @AppStorage("deeplApiKey") private var deeplApiKey: String = ""
    @State private var isTestRunning = false
    @State private var testStatus: String?
    @State private var isTestSuccessful: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(
                title: "DeepL API Key",
                description: "Insert your DeepL Developer API key to unlock full transcript translation. Both Free and Pro keys are supported."
            )
            
            HStack(spacing: 12) {
                CustomSecureField(placeholder: "Enter DeepL Auth Key (e.g. ...:fx)", text: $deeplApiKey)
                
                PrimaryButton(
                    title: "Test Key",
                    loadingTitle: "Testing...",
                    isLoading: isTestRunning,
                    isDisabled: deeplApiKey.isEmpty,
                    action: testAPIKey
                )
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
