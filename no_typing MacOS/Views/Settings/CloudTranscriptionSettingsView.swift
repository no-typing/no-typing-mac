import SwiftUI

struct CloudTranscriptionSettingsView: View {
    @AppStorage("cloudOpenAIApiKey") private var openAIApiKey: String = ""
    @AppStorage("cloudElevenLabsApiKey") private var elevenLabsApiKey: String = ""
    @AppStorage("cloudDeepgramApiKey") private var deepgramApiKey: String = ""
    @AppStorage("cloudGroqApiKey") private var groqApiKey: String = ""
    @AppStorage("cloudCustomURL") private var customURL: String = ""
    @AppStorage("cloudCustomApiKey") private var customApiKey: String = ""
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Cloud Transcriptions")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                Text("Configure external engines to bypass local Voice Models and access advanced features like fast diarization.")
                    .font(.subheadline)
                    .foregroundColor(ThemeColors.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 16) {
                // OpenAI
                settingRow(
                    title: "OpenAI Whisper API",
                    icon: "sparkles",
                    color: .purple,
                    value: $openAIApiKey,
                    placeholder: "sk-proj-...",
                    secure: true
                )
                
                Divider().background(Color.white.opacity(0.1))
                
                // Deepgram
                settingRow(
                    title: "Deepgram API (Speaker Tags)",
                    icon: "waveform",
                    color: .cyan,
                    value: $deepgramApiKey,
                    placeholder: "Token...",
                    secure: true
                )
                
                Divider().background(Color.white.opacity(0.1))
                
                // ElevenLabs
                settingRow(
                    title: "ElevenLabs API",
                    icon: "mic.fill",
                    color: .orange,
                    value: $elevenLabsApiKey,
                    placeholder: "sk_...",
                    secure: true
                )
                
                Divider().background(Color.white.opacity(0.1))
                
                // Groq
                settingRow(
                    title: "Groq Whisper API",
                    icon: "bolt.fill",
                    color: .red,
                    value: $groqApiKey,
                    placeholder: "gsk_...",
                    secure: true
                )
                
                Divider().background(Color.white.opacity(0.1))
                
                // Custom
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
                }
            }
        }
    }
    
    @ViewBuilder
    private func settingRow(title: String, icon: String, color: Color, value: Binding<String>, placeholder: String, secure: Bool) -> some View {
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
            
            if secure {
                SecureField(placeholder, text: value)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            } else {
                TextField(placeholder, text: value)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
        }
    }
}
