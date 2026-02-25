import SwiftUI

struct WhisperModelSelectionView: View {
    @ObservedObject var whisperManager = WhisperManager.shared
    @EnvironmentObject var audioManager: AudioManager
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("enableTranscriptionCleaning") private var enableTranscriptionCleaning = true
    @AppStorage("enableAutoPunctuation") private var enableAutoPunctuation = true
    @AppStorage("pauseDetectionThreshold") private var pauseDetectionThreshold: Double = 1.5
    var showTitle: Bool = true
    var showDescription: Bool = true
    var compact: Bool = false
    
    // Add language selection state
    @AppStorage("selectedLanguage") private var selectedLanguage: String = "auto"
    
    // Add tone selection state
    @AppStorage("selectedTone") private var selectedTone: String = "professional"
    
    // Transcription Service properties
    @AppStorage("useGroqAPI") private var useGroqAPI = false
    @State private var groqAPIKeyInput: String = ""
    @State private var hasGroqKey: Bool = false
    @State private var groqKeySaveMessage: String = ""
    
    // Define tone categories
    struct ToneCategory {
        let name: String
        let icon: String
        let tones: [(name: String, code: String)]
    }
    
    private let toneCategories = [
        ToneCategory(name: "Standard", icon: "text.bubble", tones: [
            ("Professional", "professional"),
            ("Friendly", "friendly"),
            ("Casual", "casual"),
            ("Concise", "concise")
        ]),
        ToneCategory(name: "Generational", icon: "person.2.waves", tones: [
            ("Gen Z", "genz"),
            ("Millennial", "millennial"),
            ("Boomer", "boomer"),
            ("Internet Culture", "internet")
        ]),
        ToneCategory(name: "Professional", icon: "briefcase", tones: [
            ("Tech Bro", "techbro"),
            ("Academic", "academic"),
            ("Sports Commentator", "sports"),
            ("News Anchor", "news"),
            ("Motivational Speaker", "motivational")
        ]),
        ToneCategory(name: "Creative", icon: "paintpalette", tones: [
            ("Shakespearean", "shakespeare"),
            ("Noir Detective", "noir"),
            ("Fantasy/Medieval", "fantasy"),
            ("Sci-Fi", "scifi"),
            ("Pirate", "pirate")
        ]),
        ToneCategory(name: "Mood", icon: "theatermasks", tones: [
            ("Passive Aggressive", "passive"),
            ("Overly Dramatic", "dramatic"),
            ("Sarcastic", "sarcastic"),
            ("Wholesome", "wholesome"),
            ("Conspiracy Theorist", "conspiracy")
        ]),
        ToneCategory(name: "Regional", icon: "map", tones: [
            ("Southern Charm", "southern"),
            ("British Posh", "british"),
            ("Surfer Dude", "surfer"),
            ("New York Hustle", "newyork")
        ]),
        ToneCategory(name: "Unique", icon: "sparkles", tones: [
            ("Corporate Email", "corporate"),
            ("Mom Text", "mom"),
            ("Fortune Cookie", "fortune"),
            ("Infomercial", "infomercial"),
            ("Robot/AI", "robot")
        ])
    ]
    
    // Computed property to get all tones as a flat list
    private var allTones: [(name: String, code: String)] {
        toneCategories.flatMap { $0.tones }
    }
    
    // Define supported languages with Whisper's language codes
    private let supportedLanguages: [(name: String, code: String)] = [
        ("Auto", "auto"),
        ("English", "en"),
        ("Chinese", "zh"),
        ("German", "de"),
        ("Spanish", "es"),
        ("Russian", "ru"),
        ("Korean", "ko"),
        ("French", "fr"),
        ("Japanese", "ja"),
        ("Portuguese", "pt"),
        ("Turkish", "tr"),
        ("Polish", "pl"),
        ("Italian", "it"),
        ("Vietnamese", "vi"),
        ("Dutch", "nl"),
        ("Persian", "fa"),
        ("Arabic", "ar")
    ]
    
    private func getGradientForModel(_ id: String) -> LinearGradient {
        switch id {
        case "small", "Small":
            return LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "large_v3", "largev3":
            return LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "large_v3_turbo", "largev3turbo":
            return LinearGradient(colors: [.blue, .teal], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "distil_large_v3.5":
            return LinearGradient(colors: [.pink, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            return LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom)
        }
    }
    
    private func getPrimaryColorForModel(_ id: String) -> Color {
        switch id {
        case "small", "Small": return .purple
        case "large_v3", "largev3": return .orange
        case "large_v3_turbo", "largev3turbo": return .blue
        case "distil_large_v3.5": return .pink
        default: return .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if showTitle {
                Text("Model Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                    // Voice Control Settings Section
                    VStack(alignment: .leading, spacing: 16) {
                        // Model Management Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "waveform")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                                Text("Speech to Text Model")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                            }
                            
                            // Model Selection Dropdown (Removed, integrated into Cards)
                            // Show warning if no models are available
                            if whisperManager.availableModels.allSatisfy({ !$0.isAvailable }) && !whisperManager.isDownloading {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .font(.system(size: 16))
                                    Text("No speech models downloaded. Select a model to download and enable transcription.")
                                        .font(.subheadline)
                                        .foregroundColor(.orange)
                                }
                                .padding(12)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(12)
                            }
                            
                            // Model Radio Cards
                            HStack(alignment: .top, spacing: 12) {
                                ForEach(whisperManager.availableModels, id: \.id) { model in
                                    let isSelected = model.id == whisperManager.selectedModelSize
                                    
                                    Button(action: {
                                        if model.isAvailable {
                                            whisperManager.selectModel(modelSize: model.id)
                                        } else if !whisperManager.isDownloading {
                                            whisperManager.downloadModel(modelSize: model.id)
                                        }
                                    }) {
                                        VStack(alignment: .leading, spacing: 12) {
                                            // Top Row: Icon and Status Indicator
                                            HStack(alignment: .top) {
                                                ZStack {
                                                    Circle()
                                                        .fill(getGradientForModel(model.id))
                                                        .frame(width: 36, height: 36)
                                                    Image(systemName: model.displayInfo.icon)
                                                        .foregroundColor(.white)
                                                        .font(.system(size: 16))
                                                }
                                                
                                                Spacer()
                                                
                                                if !model.isAvailable {
                                                    if whisperManager.isDownloading && model.id == whisperManager.downloadingModelSize {
                                                        Text("\(Int(whisperManager.downloadProgress * 100))%")
                                                            .font(.system(size: 11, weight: .bold))
                                                            .foregroundColor(ThemeColors.accent)
                                                    } else {
                                                        Image(systemName: "icloud.and.arrow.down")
                                                            .font(.system(size: 18))
                                                            .foregroundColor(Color.gray.opacity(0.6))
                                                    }
                                                } else {
                                                    HStack(spacing: 8) {
                                                        if !isSelected {
                                                            Button(action: {
                                                                whisperManager.deleteModel(modelSize: model.id)
                                                            }) {
                                                                Image(systemName: "trash")
                                                                    .font(.system(size: 14))
                                                                    .foregroundColor(.red.opacity(0.8))
                                                            }
                                                            .buttonStyle(.plain)
                                                        }
                                                        
                                                        if isSelected {
                                                            Image(systemName: "checkmark.circle.fill")
                                                                .font(.system(size: 18))
                                                                .foregroundColor(ThemeColors.accent)
                                                        } else {
                                                            Image(systemName: "circle")
                                                                .font(.system(size: 18))
                                                                .foregroundColor(Color.gray.opacity(0.4))
                                                        }
                                                    }
                                                }
                                            }
                                            
                                            // Title and description (recommendation mapping to subtitle)
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(model.displayInfo.displayName)
                                                    .font(.system(size: 15, weight: .semibold))
                                                    .foregroundColor(.white)
                                                
                                                Text(model.displayInfo.recommendation ?? model.displayInfo.description)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(ThemeColors.secondaryText)
                                                    .lineLimit(3)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                            
                                            Spacer(minLength: 0)
                                            
                                            Text(model.id)
                                                .font(.system(size: 10, weight: .bold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(getPrimaryColorForModel(model.id).opacity(0.2))
                                                .foregroundColor(getPrimaryColorForModel(model.id))
                                                .cornerRadius(4)
                                                
                                            // Keep progress bar layout roughly the same scale but underneath
                                            if !model.isAvailable && whisperManager.isDownloading && model.id == whisperManager.downloadingModelSize {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    GeometryReader { geometry in
                                                        ZStack(alignment: .leading) {
                                                            Rectangle()
                                                                .frame(width: geometry.size.width, height: 4)
                                                                .opacity(0.3)
                                                                .foregroundColor(.gray)
                                                            
                                                            Rectangle()
                                                                .frame(width: geometry.size.width * CGFloat(whisperManager.downloadProgress), height: 4)
                                                                .foregroundColor(ThemeColors.accent)
                                                        }
                                                        .cornerRadius(2)
                                                    }
                                                    .frame(height: 4)
                                                    
                                                    HStack {
                                                        Spacer()
                                                        Button(action: {
                                                            whisperManager.cancelDownload()
                                                        }) {
                                                            Image(systemName: "xmark.circle.fill")
                                                                .font(.system(size: 14))
                                                                .foregroundColor(.gray.opacity(0.8))
                                                        }
                                                        .buttonStyle(.plain)
                                                    }
                                                }
                                                .padding(.top, 4)
                                            }
                                        }
                                        .padding(14)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(Color(red: 25/255, green: 30/255, blue: 40/255))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .stroke(isSelected ? ThemeColors.accent : Color.white.opacity(0.05), lineWidth: isSelected ? 2 : 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .onHover { hovering in
                                        if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                                    }
                                }
                            }
                            
                            if let errorMessage = whisperManager.errorMessage {
                                Text(errorMessage)
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                                    .lineLimit(2)
                            }
                        }
                        
                        // Divider()
                        //     .padding(.vertical, 8)
                        
                        // // Transcription Service Section
                        // VStack(alignment: .leading, spacing: 12) {
                        //     HStack {
                        //         Image(systemName: "cloud")
                        //             .font(.system(size: 16))
                        //             .foregroundColor(.blue)
                        //         Text("Slow Device?")
                        //             .font(.body)
                        //             .fontWeight(.medium)
                        //             .foregroundColor(.white)
                        //     }
                            
                        //     Text("Try remote transcription for faster output on slower devices.")
                        //         .font(.subheadline)
                        //         .foregroundColor(ThemeColors.secondaryText)
                            
                        //     VStack(alignment: .leading, spacing: 12) {
                        //         // Groq API Toggle
                        //         SettingsToggleRow(
                        //             icon: "bolt.fill",
                        //             title: "Use Free Groq API",
                        //             isOn: $useGroqAPI,
                        //             iconGradient: LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                        //         )
                                
                        //         // API Key Section (shown when Groq is enabled)
                        //         if useGroqAPI {
                        //             VStack(alignment: .leading, spacing: 8) {
                        //                 Text("Groq API Key")
                        //                     .font(.body)
                        //                     .fontWeight(.semibold)
                        //                     .foregroundColor(.white)
                                        
                        //                 HStack(spacing: 8) {
                        //                     SecureField("Enter your API key and hit Enter", text: $groqAPIKeyInput)
                        //                         .textFieldStyle(.roundedBorder)
                        //                         .padding(4)
                        //                         .background(Color.white.opacity(0.1))
                        //                         .cornerRadius(6)
                        //                         .onSubmit {
                        //                             saveGroqAPIKey()
                        //                         }
                                            
                        //                     Button("Get Free API Key") {
                        //                         if let url = URL(string: "https://console.groq.com/keys") {
                        //                             NSWorkspace.shared.open(url)
                        //                         }
                        //                     }
                        //                     .buttonStyle(.plain)
                        //                     .padding(.horizontal, 12)
                        //                     .padding(.vertical, 6)
                        //                     .background(ThemeColors.pillSelection)
                        //                     .foregroundColor(.white)
                        //                     .cornerRadius(8)
                        //                 }
                                        
                        //                 if hasGroqKey {
                        //                     Text("Current API Key: \(GroqTranscriptionService.shared.maskedAPIKey)")
                        //                         .font(.subheadline)
                        //                         .foregroundColor(ThemeColors.secondaryText)
                        //                 }
                                        
                        //                 if !groqKeySaveMessage.isEmpty {
                        //                     Text(groqKeySaveMessage)
                        //                         .font(.subheadline)
                        //                         .foregroundColor(ThemeColors.accent)
                        //                 }
                        //             }
                        //             .padding(.leading, 12)
                        //             .padding(.top, 4)
                        //         }
                        //     }
                        // }
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // Language Selection
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "globe")
                                    .font(.system(size: 14))
                                    .foregroundColor(.blue)
                                Text("Recognition Language")
                                    .font(.body)
                                    .foregroundColor(.white)
                            }
                            
                            Text("Select the primary language you'll be speaking in")
                                .font(.subheadline)
                                .foregroundColor(ThemeColors.secondaryText)
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                                ForEach(supportedLanguages, id: \.code) { language in
                                    let isSelected = language.code == self.selectedLanguage
                                    RadioGridCard(
                                        title: language.name,
                                        icon: nil,
                                        iconGradient: nil,
                                        isSelected: isSelected
                                    ) {
                                        self.selectedLanguage = language.code
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                        .onChange(of: selectedLanguage) { newValue in
                            UserDefaults.standard.set(newValue, forKey: "selectedLanguage")
                            NotificationCenter.default.post(
                                name: NSNotification.Name("SelectedLanguageChanged"),
                                object: nil,
                                userInfo: ["language": newValue]
                            )
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // Transcription Mode and Settings
                        VStack(alignment: .leading, spacing: 12) {
                            // Mode Selection
                            SettingsToggleRow(
                                icon: audioManager.isStreamingMode ? "waveform.badge.plus" : "square.stack.3d.up",
                                title: "Streaming Mode",
                                isOn: Binding(
                                    get: { audioManager.isStreamingMode },
                                    set: { _ in audioManager.toggleTranscriptionMode() }
                                ),
                                iconGradient: LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            
                            Text(audioManager.isStreamingMode ? 
                                 "Text appears in real-time as you speak" : 
                                 "Text is accumulated during recording and processed simultaneously when you finish, then inserted as a single chunk")
                                .font(.subheadline)
                                .foregroundColor(ThemeColors.secondaryText)
                                .padding(.leading, 12)
                            
                            // Pause Detection Duration (only show in streaming mode)
                            if audioManager.isStreamingMode {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "timer")
                                            .font(.system(size: 14))
                                            .foregroundColor(.blue)
                                        Text("Pause Detection")
                                            .font(.body)
                                            .foregroundColor(.white)
                                    }
                                    
                                    Text("Longer pauses provide better accuracy. Shorter segments may reduce quality.")
                                        .font(.subheadline)
                                        .foregroundColor(ThemeColors.secondaryText)
                                    
                                    let thresholds: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5, 2.75, 3.0]
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(thresholds, id: \.self) { threshold in
                                                RadioGridCard(
                                                    title: "\(String(format: "%g", threshold))s",
                                                    icon: nil,
                                                    iconGradient: nil,
                                                    isSelected: self.pauseDetectionThreshold == threshold
                                                ) {
                                                    self.pauseDetectionThreshold = threshold
                                                }
                                            }
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                                .padding(.leading, 12)
                                .onChange(of: pauseDetectionThreshold) { newValue in
                                    // Notify the speech recognizer of the change
                                    NotificationCenter.default.post(
                                        name: NSNotification.Name("PauseDetectionThresholdChanged"),
                                        object: nil,
                                        userInfo: ["threshold": newValue]
                                    )
                                }
                            }
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // Auto-Punctuation Toggle
                        VStack(alignment: .leading, spacing: 8) {
                            SettingsToggleRow(
                                icon: "text.justify.left",
                                title: "Auto-Punctuation",
                                isOn: $enableAutoPunctuation,
                                iconGradient: LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            
                            Text("Automatically adds a period at the end of your transcriptions")
                                .font(.subheadline)
                                .foregroundColor(ThemeColors.secondaryText)
                                .padding(.leading, 12)
                        }
                        
                        Divider()
                        
                        // AI Rewrite Toggle
                        VStack(alignment: .leading, spacing: 8) {
                            
                            SettingsToggleRow(
                                icon: "sparkles",
                                title: "AI Rewrite",
                                isOn: $enableTranscriptionCleaning,
                                iconGradient: LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            
                            if enableTranscriptionCleaning {
                                Text("Uses Apple Intelligence to improve grammar and sentence structure")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                // Tone Selection
                                HStack(spacing: 8) {
                                    Image(systemName: "text.bubble")
                                        .font(.system(size: 14))
                                        .foregroundColor(.blue)
                                    Text("Writing Tone")
                                        .font(.body)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Picker("Tone", selection: $selectedTone) {
                                        ForEach(toneCategories, id: \.name) { category in
                                            Section(header: Text(category.name)) {
                                                ForEach(category.tones, id: \.code) { tone in
                                                    Text(tone.name)
                                                        .tag(tone.code)
                                                }
                                            }
                                        }
                                    }
                                    .frame(width: 200)
                                    .onChange(of: selectedTone) { newValue in
                                        UserDefaults.standard.set(newValue, forKey: "selectedTone")
                                        NotificationCenter.default.post(
                                            name: NSNotification.Name("SelectedToneChanged"),
                                            object: nil,
                                            userInfo: ["tone": newValue]
                                        )
                                    }
                                }
                                .padding(.top, 8)
                                
                                Text("Choose how AI rewrites your transcriptions")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.clear)
                    .onAppear {
                        loadGroqAPIKey()
                    }
                    .onChange(of: useGroqAPI) { newValue in
                        if newValue {
                            loadGroqAPIKey()
                        }
                    }
                }
            
        }
    }
    
    // MARK: - Groq API Handlers
    
    private func saveGroqAPIKey() {
        let key = groqAPIKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            print("⚠️ Groq API key is empty, not saving")
            return
        }
        // groq api key must begin with "gsk_"
        if !key.hasPrefix("gsk_") {
            print("⚠️ Groq API keys begin with 'gsk_'. Please visit https://console.groq.com/ to generate a new API key. (Groq.com and not Grok xAI)")
            return
        }
        print("🔑 Saving Groq API key (\(key.prefix(4))...)")
        GroqTranscriptionService.shared.saveAPIKey(key)
        hasGroqKey = true
        groqKeySaveMessage = "✓ API Key saved successfully"
        // Clear the save message after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            groqKeySaveMessage = ""
        }
        print("🔑 Groq API key saved. hasAPIKey: \(GroqTranscriptionService.shared.hasAPIKey)")
    }
    
    private func loadGroqAPIKey() {
        hasGroqKey = GroqTranscriptionService.shared.hasAPIKey
        if hasGroqKey {
            groqAPIKeyInput = GroqTranscriptionService.shared.apiKey ?? ""
            print("🔑 Loaded existing Groq API key (\(groqAPIKeyInput.prefix(4))...)")
        } else {
            groqAPIKeyInput = ""
            print("🔑 No existing Groq API key found")
        }
    }
}
