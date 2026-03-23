import SwiftUI

struct WhisperModelSelectionView: View {
    @ObservedObject var whisperManager = WhisperManager.shared
    @EnvironmentObject var audioManager: AudioManager
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("enableTranscriptionCleaning") private var enableTranscriptionCleaning = true
    @AppStorage("enableAutoPunctuation") private var enableAutoPunctuation = true
    @AppStorage("ignoreSilenceSegments") private var ignoreSilenceSegments = true
    @AppStorage("pauseDetectionThreshold") private var pauseDetectionThreshold: Double = 1.5
    var showTitle: Bool = true
    var showDescription: Bool = true
    var compact: Bool = false
    
    // Add language selection state
    @AppStorage("selectedLanguage") private var selectedLanguage: String = "auto"
    
    // Add tone selection state
    @AppStorage("selectedTone") private var selectedTone: String = "professional"
    
    // Transcription Service properties
    
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
    
    // Define supported languages with Whisper's language codes (all 99 supported languages)
    private let supportedLanguages: [(name: String, code: String)] = [
        ("Auto", "auto"),
        ("Afrikaans", "af"),
        ("Amharic", "am"),
        ("Arabic", "ar"),
        ("Armenian", "hy"),
        ("Assamese", "as"),
        ("Azerbaijani", "az"),
        ("Bashkir", "ba"),
        ("Belarusian", "be"),
        ("Bengali", "bn"),
        ("Bosnian", "bs"),
        ("Breton", "br"),
        ("Bulgarian", "bg"),
        ("Burmese", "my"),
        ("Catalan", "ca"),
        ("Chinese", "zh"),
        ("Croatian", "hr"),
        ("Czech", "cs"),
        ("Danish", "da"),
        ("Dutch", "nl"),
        ("English", "en"),
        ("Estonian", "et"),
        ("Faroese", "fo"),
        ("Finnish", "fi"),
        ("French", "fr"),
        ("Galician", "gl"),
        ("Georgian", "ka"),
        ("German", "de"),
        ("Greek", "el"),
        ("Gujarati", "gu"),
        ("Haitian Creole", "ht"),
        ("Hausa", "ha"),
        ("Hawaiian", "haw"),
        ("Hebrew", "he"),
        ("Hindi", "hi"),
        ("Hungarian", "hu"),
        ("Icelandic", "is"),
        ("Indonesian", "id"),
        ("Italian", "it"),
        ("Japanese", "ja"),
        ("Javanese", "jw"),
        ("Kannada", "kn"),
        ("Kazakh", "kk"),
        ("Khmer", "km"),
        ("Korean", "ko"),
        ("Lao", "lo"),
        ("Latin", "la"),
        ("Latvian", "lv"),
        ("Lingala", "ln"),
        ("Lithuanian", "lt"),
        ("Luxembourgish", "lb"),
        ("Macedonian", "mk"),
        ("Malagasy", "mg"),
        ("Malay", "ms"),
        ("Malayalam", "ml"),
        ("Maltese", "mt"),
        ("Maori", "mi"),
        ("Marathi", "mr"),
        ("Mongolian", "mn"),
        ("Nepali", "ne"),
        ("Norwegian", "no"),
        ("Norwegian Nynorsk", "nn"),
        ("Occitan", "oc"),
        ("Pashto", "ps"),
        ("Persian", "fa"),
        ("Polish", "pl"),
        ("Portuguese", "pt"),
        ("Punjabi", "pa"),
        ("Romanian", "ro"),
        ("Russian", "ru"),
        ("Sanskrit", "sa"),
        ("Serbian", "sr"),
        ("Shona", "sn"),
        ("Sindhi", "sd"),
        ("Sinhala", "si"),
        ("Slovak", "sk"),
        ("Slovenian", "sl"),
        ("Somali", "so"),
        ("Spanish", "es"),
        ("Sundanese", "su"),
        ("Swahili", "sw"),
        ("Swedish", "sv"),
        ("Tagalog", "tl"),
        ("Tajik", "tg"),
        ("Tamil", "ta"),
        ("Tatar", "tt"),
        ("Telugu", "te"),
        ("Thai", "th"),
        ("Tibetan", "bo"),
        ("Turkish", "tr"),
        ("Turkmen", "tk"),
        ("Ukrainian", "uk"),
        ("Urdu", "ur"),
        ("Uzbek", "uz"),
        ("Vietnamese", "vi"),
        ("Welsh", "cy"),
        ("Yiddish", "yi"),
        ("Yoruba", "yo"),
        ("Zulu", "zu")
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
        case "parakeet_v2":
            return LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "parakeet_v3":
            return LinearGradient(colors: [.green, .teal], startPoint: .topLeading, endPoint: .bottomTrailing)
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
        case "parakeet_v2": return .green
        case "parakeet_v3": return .teal
        default: return .gray
        }
    }
    
    static func downloadSizeForModel(_ id: String) -> String {
        switch id {
        case "small", "Small": return "466 MB"
        case "large_v3", "largev3": return "3.1 GB"
        case "large_v3_turbo", "largev3turbo": return "1.6 GB"
        case "distil_large_v3.5": return "756 MB"
        case "parakeet_v2": return "460 MB"
        case "parakeet_v3": return "465 MB"
        default: return ""
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
                            
                            Text("Local Models")
                            .font(.title2.weight(.bold))
                            .foregroundColor(.white)
                            
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
                            
                            // Model Radio Cards - Flex Grid Layout
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], alignment: .leading, spacing: 12) {
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
                                            // Top Row: Name and Status Indicator
                                            HStack(alignment: .top) {
                                                Text(model.displayInfo.displayName)
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(.white)
                                                
                                                Spacer()
                                                
                                                if !model.isAvailable {
                                                    if whisperManager.isDownloading && model.id == whisperManager.downloadingModelSize {
                                                        HStack(spacing: 6) {
                                                            Text(Self.downloadSizeForModel(model.id))
                                                                .font(.system(size: 10, weight: .medium))
                                                                .foregroundColor(Color.gray.opacity(0.8))
                                                            Text("\(Int(whisperManager.downloadProgress * 100))%")
                                                                .font(.system(size: 11, weight: .bold))
                                                                .foregroundColor(ThemeColors.accent)
                                                        }
                                                    } else {
                                                        HStack(spacing: 4) {
                                                            Text(Self.downloadSizeForModel(model.id))
                                                                .font(.system(size: 10, weight: .medium))
                                                                .foregroundColor(Color.gray.opacity(0.6))
                                                            Image(systemName: "icloud.and.arrow.down")
                                                                .font(.system(size: 18))
                                                                .foregroundColor(Color.gray.opacity(0.6))
                                                        }
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
                                            
                                            // Description
                                            Text(model.displayInfo.recommendation ?? model.displayInfo.description)
                                                .font(.system(size: 12))
                                                .foregroundColor(ThemeColors.secondaryText)
                                                .lineLimit(3)
                                                .fixedSize(horizontal: false, vertical: true)
                                            
                                            Spacer(minLength: 0)
                                            
                                            Text(model.id)
                                                .font(.system(size: 10, weight: .bold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(getPrimaryColorForModel(model.id).opacity(0.2))
                                                .foregroundColor(getPrimaryColorForModel(model.id))
                                                .cornerRadius(4)
                                            
                                            // Requirements badge for Parakeet models
                                            // if ParakeetManager.isParakeetModel(model.id) {
                                            //     Text(ParakeetManager.requirementsDescription)
                                            //         .font(.system(size: 9))
                                            //         .foregroundColor(.green.opacity(0.8))
                                            //         .padding(.top, 2)
                                            // }
                                                
                                            // Progress bar for downloading
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
                                        .frame(minWidth: 160, maxHeight: .infinity, alignment: .topLeading)
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
                                    .lineLimit(4)
                                    .textSelection(.enabled)
                            }
                        }
                        
                        // Divider()
                        //     .padding(.vertical, 8)
                        
                        // // Transcription Service Section
                        // VStack(alignment: .leading, spacing: 12) {
                        //     HStack {
                        //         Image(systemName: "cloud")

                        
                        Divider()
                            .padding(.vertical, 8)
                        
                
                        CloudTranscriptionSettingsView()

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
                                Spacer()
                                Picker("Language", selection: $selectedLanguage) {
                                    ForEach(supportedLanguages, id: \.code) { language in
                                        Text(language.name).tag(language.code)
                                    }
                                }
                                .frame(width: 200)
                            }
                            
                            Text("Select the primary language you'll be speaking in")
                                .font(.subheadline)
                                .foregroundColor(ThemeColors.secondaryText)
                        }
                        .onChange(of: selectedLanguage) { newValue in
                            UserDefaults.standard.set(newValue, forKey: "selectedLanguage")
                            NotificationCenter.default.post(
                                name: NSNotification.Name("SelectedLanguageChanged"),
                                object: nil,
                                userInfo: ["language": newValue]
                            )
                        }
                        
                        // Divider()
                        //     .padding(.vertical, 8)
                        
                        // // Transcription Mode and Settings
                        // VStack(alignment: .leading, spacing: 12) {
                        //     // Mode Selection
                        //     SettingsToggleRow(
                        //         icon: audioManager.isStreamingMode ? "waveform.badge.plus" : "square.stack.3d.up",
                        //         title: "Streaming Mode",
                        //         isOn: Binding(
                        //             get: { audioManager.isStreamingMode },
                        //             set: { _ in audioManager.toggleTranscriptionMode() }
                        //         ),
                        //         iconGradient: LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
                        //     )
                            
                        //     Text(audioManager.isStreamingMode ? 
                        //          "Text appears in real-time as you speak" : 
                        //          "Text is accumulated during recording and processed simultaneously when you finish, then inserted as a single chunk")
                        //         .font(.subheadline)
                        //         .foregroundColor(ThemeColors.secondaryText)
                        //         .padding(.leading, 12)
                            
                        //     // Pause Detection Duration (only show in streaming mode)
                        //     if audioManager.isStreamingMode {
                        //         VStack(alignment: .leading, spacing: 12) {
                        //             HStack(spacing: 8) {
                        //                 Image(systemName: "timer")
                        //                     .font(.system(size: 14))
                        //                     .foregroundColor(.blue)
                        //                 Text("Pause Detection")
                        //                     .font(.body)
                        //                     .foregroundColor(.white)
                        //             }
                                    
                        //             Text("Longer pauses provide better accuracy. Shorter segments may reduce quality.")
                        //                 .font(.subheadline)
                        //                 .foregroundColor(ThemeColors.secondaryText)
                                    
                        //             let thresholds: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5, 2.75, 3.0]
                        //             ScrollView(.horizontal, showsIndicators: false) {
                        //                 HStack(spacing: 8) {
                        //                     ForEach(thresholds, id: \.self) { threshold in
                        //                         RadioGridCard(
                        //                             title: "\(String(format: "%g", threshold))s",
                        //                             icon: nil,
                        //                             iconGradient: nil,
                        //                             isSelected: self.pauseDetectionThreshold == threshold
                        //                         ) {
                        //                             self.pauseDetectionThreshold = threshold
                        //                         }
                        //                     }
                        //                 }
                        //                 .padding(.vertical, 4)
                        //             }
                        //         }
                        //         .padding(.leading, 12)
                        //         .onChange(of: pauseDetectionThreshold) { newValue in
                        //             // Notify the speech recognizer of the change
                        //             NotificationCenter.default.post(
                        //                 name: NSNotification.Name("PauseDetectionThresholdChanged"),
                        //                 object: nil,
                        //                 userInfo: ["threshold": newValue]
                        //             )
                        //         }
                        //     }
                        // }
                        
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
                            .padding(.vertical, 8)
                        
                        // Ignore Sound Tags Toggle
                        VStack(alignment: .leading, spacing: 8) {
                            SettingsToggleRow(
                                icon: "speaker.slash",
                                title: "Ignore Sound Tags",
                                isOn: $ignoreSilenceSegments,
                                iconGradient: LinearGradient(colors: [.gray, .black.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            
                            Text("Automatically removes tags like [SILENCE] or [MUSIC] from transcripts")
                                .font(.subheadline)
                                .foregroundColor(ThemeColors.secondaryText)
                                .padding(.leading, 12)
                        }
                        
                        Divider()
                        
                        // AI Rewrite Settings
                        VStack(alignment: .leading, spacing: 8) {
                            AIRewriteSettingsView().padding(.bottom, 16)
                            
                            AITranslationSettingsView()
                            
                            if enableTranscriptionCleaning {
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
                                }.padding(16)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                                
                                Text("Choose how AI rewrites your transcriptions")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.clear)
                }
            
        }
    }
}
