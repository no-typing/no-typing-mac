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
    
    @AppStorage("cloudTranscriptionEnabled") private var useCloudEngine: Bool = false
    
    // Transcription Service properties
    @State private var showCustomModelSheet = false
    @State private var selectedModelForDetails: WhisperModelInfo?
    
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
    
    private func getGradientForModel(_ id: String) -> LinearGradient {
        switch id {
        case "base", "Base":
            return LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "small", "Small":
            return LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "large_v3", "largev3":
            return LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "large_v3_turbo", "largev3turbo":
            return LinearGradient(colors: [.blue, .teal], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "distil_large_v3.5":
            return LinearGradient(colors: [.pink, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "distil_large_v2":
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
        case "base", "Base": return .cyan
        case "small", "Small": return .purple
        case "large_v3", "largev3": return .orange
        case "large_v3_turbo", "largev3turbo": return .blue
        case "distil_large_v3.5": return .pink
        case "distil_large_v2": return .pink
        case "parakeet_v2": return .green
        case "parakeet_v3": return .teal
        default: return .gray
        }
    }
    
    static func downloadSizeForModel(_ id: String) -> String {
        switch id {
        case "base", "Base": return "141 MB"
        case "small", "Small": return "466 MB"
        case "large_v3", "largev3": return "3.1 GB"
        case "large_v3_turbo", "largev3turbo": return "1.6 GB"
        case "distil_large_v3.5": return "756 MB"
        case "distil_large_v2": return "584 MB"
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
                            
                            HStack {
                                Text("Local Models")
                                    .font(.title2.weight(.bold))
                                    .foregroundColor(.white)
                                
                                if useCloudEngine {
                                    Spacer()
                                    HStack(spacing: 6) {
                                        Image(systemName: "cloud.fill")
                                            .font(.system(size: 10))
                                            .foregroundColor(.yellow)
                                        Text("Cloud model is in use")
                                            .font(.caption.weight(.medium))
                                            .foregroundColor(.yellow)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(6)
                                }
                            }
                            
                            // Intel Mac notice — Metal GPU acceleration is Apple Silicon only
                            #if !arch(arm64)
                            HStack(spacing: 10) {
                                Image(systemName: "cpu")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Intel Mac — CPU-only Transcription")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.orange)
                                    Text("Metal GPU acceleration is only available on Apple Silicon. Transcription will be slower on Intel Macs.")
                                        .font(.system(size: 11))
                                        .foregroundColor(.orange.opacity(0.8))
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.orange.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.orange.opacity(0.25), lineWidth: 1)
                            )
                            .cornerRadius(10)
                            #endif
                            
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
                                                        HStack(spacing: 8) {
                                                            if model.id.hasPrefix("custom_") {
                                                                Button(action: {
                                                                    whisperManager.deleteModel(modelSize: model.id)
                                                                }) {
                                                                    Image(systemName: "trash")
                                                                        .font(.system(size: 14))
                                                                        .foregroundColor(.red.opacity(0.8))
                                                                }
                                                                .buttonStyle(.plain)
                                                            }
                                                            
                                                            HStack(spacing: 4) {
                                                                Text(Self.downloadSizeForModel(model.id))
                                                                    .font(.system(size: 10, weight: .medium))
                                                                    .foregroundColor(Color.gray.opacity(0.6))
                                                                Image(systemName: "icloud.and.arrow.down")
                                                                    .font(.system(size: 18))
                                                                    .foregroundColor(Color.gray.opacity(0.6))
                                                            }
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
                                            
                                            HStack(spacing: 4) {
                                                Text(model.id)
                                                    .font(.system(size: 10, weight: .bold))
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(getPrimaryColorForModel(model.id).opacity(0.2))
                                                    .foregroundColor(getPrimaryColorForModel(model.id))
                                                    .cornerRadius(4)
                                                
                                                Button(action: {
                                                    selectedModelForDetails = model
                                                }) {
                                                    Image(systemName: "info.circle")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(ThemeColors.secondaryText.opacity(0.7))
                                                }
                                                .buttonStyle(.plain)
                                                .popover(
                                                    isPresented: Binding(
                                                        get: { selectedModelForDetails?.id == model.id },
                                                        set: { isPresented in
                                                            if !isPresented && selectedModelForDetails?.id == model.id {
                                                                selectedModelForDetails = nil
                                                            }
                                                        }
                                                    )
                                                ) {
                                                    if let selected = selectedModelForDetails {
                                                        ModelDetailsPopover(model: selected)
                                                    }
                                                }
                                            }
                                            
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
                            
                            // Add Custom Model Button
                            Button(action: {
                                showCustomModelSheet = true
                            }) {
                                VStack(alignment: .center, spacing: 12) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundColor(ThemeColors.secondaryText)
                                    
                                    Text("Add Custom Model")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(ThemeColors.secondaryText)
                                }
                                .frame(minWidth: 160, maxWidth: .infinity, minHeight: 140, maxHeight: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                                )
                                .contentShape(Rectangle())
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
                .opacity(useCloudEngine ? 0.5 : 1.0)
                .disabled(useCloudEngine)
                        
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
                                 SearchableLanguagePicker(selection: $selectedLanguage, languages: TranscriptionLanguage.all)
                                    .frame(width: 250)
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
                            
                            // Tone Selection
                            HStack(spacing: 8) {
                                Image(systemName: "text.bubble")
                                    .font(.system(size: 14))
                                    .foregroundColor(.blue)
                                Text("AI Writing Tone")
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
                            
                            AITranslationSettingsView().padding(.top, 16)
                        }
                        
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.clear)
                    .sheet(isPresented: $showCustomModelSheet) {
                        AddCustomModelView(isPresented: $showCustomModelSheet)
                    }
                }
            
    }
}

struct AddCustomModelView: View {
    @Binding var isPresented: Bool
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var downloadURL: String = ""
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Custom Model")
                .font(.title2.weight(.bold))
            
            Text("Provide an active download link to a compatible model file.")
                .font(.subheadline)
                .foregroundColor(ThemeColors.secondaryText)
                
            VStack(alignment: .leading, spacing: 12) {
                TextField("Model Name (Required)", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                TextField("Download URL (Required)", text: $downloadURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                TextField("Description (Optional)", text: $description)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Supported formats:")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(ThemeColors.secondaryText)
                Text("• Whisper: .bin (ggml format)")
                    .font(.caption)
                    .foregroundColor(ThemeColors.secondaryText)
                Text("• Sherpa-ONNX: .tar.bz2 (archive file)")
                    .font(.caption)
                    .foregroundColor(ThemeColors.secondaryText)
            }
            .padding(.top, 4)
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            HStack {
                Spacer()
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                
                Button("Save & Download") {
                    validateAndSave()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(ThemeColors.accent)
                .foregroundColor(.white)
                .cornerRadius(6)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || downloadURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.top, 8)
        }
        .padding(24)
        .frame(width: 400)
        .background(Color(red: 25/255, green: 30/255, blue: 40/255))
    }
    
    private func validateAndSave() {
        let trimmedURL = downloadURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedURL), (url.scheme == "http" || url.scheme == "https") else {
            errorMessage = "Invalid URL. Must be a valid HTTP/HTTPS link."
            return
        }
        
        let id = "custom_\(UUID().uuidString.prefix(8).lowercased())"
        
        let customModel = CustomModel(
            id: id,
            name: name,
            description: description,
            tag: "",
            downloadURL: trimmedURL
        )
        
        WhisperManager.shared.addCustomModel(customModel)
        isPresented = false
    }
}

struct ModelDetailsPopover: View {
    let model: WhisperModelInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.name)
                .font(.headline)
            
            Text(model.description)
                .font(.subheadline)
                .foregroundColor(ThemeColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Download URL:")
                    .font(.caption.weight(.bold))
                
                Text(WhisperManager.shared.getModelURL(modelSize: model.id))
                    .font(.caption)
                    .foregroundColor(.blue)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
        }
        .padding(16)
        .frame(width: 300)
    }
}
