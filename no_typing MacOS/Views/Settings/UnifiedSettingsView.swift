import SwiftUI

struct UnifiedSettingsView: View {
    @EnvironmentObject var audioManager: AudioManager
    @StateObject private var hotkeyManager = HotkeyManager.shared
    @StateObject private var whisperManager = WhisperManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedSection: SettingsSection = .recentActivity
    
    // Permission states
    @State private var hasPermissionIssues = false
    @State private var hasModelIssues = false
    @AppStorage("enableHotkeys") private var enableHotkeys = true
    @AppStorage("selectedLanguage") private var selectedLanguage: String = "auto"
    @AppStorage("cloudTranscriptionEnabled") private var useCloudEngine: Bool = false
    
    enum SettingsSection: String, CaseIterable {
        case recentActivity = "Activity"
        case modelSettings = "Models"
        case hotkeys = "Hotkeys"
        case magicActions = "Magic"
        case transcribe = "Transcribe"
        case appSettings = "Settings"
        case integrations = "Webhooks"
        case support = "Support"
        #if DEVELOPMENT
        case developer = "Developer"
        #endif
        
        var icon: String {
            switch self {
            case .recentActivity: return "clock.arrow.circlepath"
            case .modelSettings: return "waveform.circle"
            case .hotkeys: return "keyboard"
            case .magicActions: return "wand.and.stars"
            case .transcribe: return "doc.badge.plus"
            case .appSettings: return "gearshape"
            case .integrations: return "network"
            case .support: return "megaphone"
            #if DEVELOPMENT
            case .developer: return "hammer.fill"
            #endif
            }
        }
        
        var color: Color {
            switch self {
            case .recentActivity: return .indigo
            case .modelSettings: return .blue
            case .hotkeys: return .purple
            case .magicActions: return .cyan
            case .transcribe: return .pink
            case .appSettings: return .green
            case .integrations: return .teal
            case .support: return .orange
            #if DEVELOPMENT
            case .developer: return .red
            #endif
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // MARK: - Custom Sidebar
            VStack(spacing: 0) {
                // Window control spacing
                    Spacer().frame(height: 30)
                    
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(SettingsSection.allCases, id: \.self) { section in
                                sidebarItem(for: section)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 16)
                    }
                    
                    Spacer()
                }
                .frame(width: 90)
                .background(audioManager.isRecordingEnabled ? ThemeColors.sidebarBackground : ThemeColors.sidebarBackgroundDisabled)
            
            // MARK: - Main Content Area
            VStack(spacing: 0) {
                // Top bar with App Logo and Name
                HStack(spacing: 12) {
                    if let appIcon = NSImage(named: "AppIcon") {
                        Image(nsImage: appIcon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .cornerRadius(6)
                    }
                    
                    Text("No-Typing")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    if hasPermissionIssues {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedSection = .appSettings
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 10))
                                Text("Access Needed")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange)
                            .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.leading, 4)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Image(systemName: "mic.fill")
                            .foregroundColor(audioManager.isRecordingEnabled ? .white.opacity(0.6) : .red)
                        Text("Dictation")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                        Toggle("", isOn: $audioManager.isRecordingEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .scaleEffect(0.8)
                    }
                    .padding(.trailing, 0)
                    .help("Enable or disable global recording hotkeys")

                    Menu {
                        ForEach(whisperManager.availableModels) { model in
                            Button(action: {
                                if model.isAvailable {
                                    whisperManager.selectedModelSize = model.id
                                } else {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedSection = .modelSettings
                                    }
                                    whisperManager.downloadModel(modelSize: model.id)
                                }
                            }) {
                                HStack {
                                    Text(model.displayInfo.displayName)
                                    if !model.isAvailable {
                                        Image(systemName: "icloud.and.arrow.down")
                                    } else if whisperManager.selectedModelSize == model.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if let current = whisperManager.availableModels.first(where: { $0.id == whisperManager.selectedModelSize }) {
                                Text(current.displayInfo.displayName)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                            } else {
                                Text("Select Model")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            Image(systemName: "waveform.circle")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .frame(width: 140)
                    .help("Select transcription model")
                    
                    SearchableLanguagePicker(selection: $selectedLanguage, languages: TranscriptionLanguage.all)
                        .frame(width: 150)
                        .help("Select recognition language")
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
                // We use clear background here to let the main content background show through
                
                ScrollView {
                    VStack(spacing: 32) {
                        switch selectedSection {
                        case .recentActivity:
                            historySection
                        case .modelSettings:
                            modelSettingsSection
                        case .hotkeys:
                            hotkeysSection
                        case .magicActions:
                            magicActionsSection
                        case .transcribe:
                            transcribeSection
                        case .appSettings:
                            appSettingsSection
                        case .integrations:
                            integrationsSection
                        case .support:
                            SupportView()
                        #if DEVELOPMENT
                        case .developer:
                            developerSection
                        #endif
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ThemeColors.contentBackground)
        }
        .ignoresSafeArea()
        .frame(minWidth: 800, idealWidth: 1000, maxWidth: .infinity, minHeight: 600)

        .onAppear {
            checkForIssues()
        }
        .onChange(of: selectedLanguage) { newValue in
            NotificationCenter.default.post(
                name: NSNotification.Name("SelectedLanguageChanged"),
                object: nil,
                userInfo: ["language": newValue]
            )
        }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            checkForIssues()
        }
    }
    
    private func sidebarItem(for section: SettingsSection) -> some View {
        let isSelected = selectedSection == section
        let hasWarning = (section == .appSettings && hasPermissionIssues) ||
                         (section == .modelSettings && hasModelIssues)
        
        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedSection = section
            }
        }) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 6) {
                    Image(systemName: section.icon)
                        .font(.system(size: 20, weight: .light))
                        .foregroundColor(isSelected ? .white : .white.opacity(0.8))
                    
                    Text(section.rawValue)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(isSelected ? .white : .white.opacity(0.8))
                        .lineLimit(1)
                }
                .padding(.vertical, 14)
                .frame(width: 72)
                .background(isSelected ? ThemeColors.pillSelection : Color.clear)
                .overlay(    
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.clear : Color.white.opacity(0.15), lineWidth: 0.5)
                )
                .cornerRadius(12)
                .contentShape(Rectangle())
                
                if hasWarning {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .offset(x: -6, y: 6)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func checkForIssues() {
        // Check permissions
        PermissionManager.shared.checkMicrophonePermission { micGranted in
            let accessibilityGranted = PermissionManager.shared.checkAccessibilityPermission()
            
            PermissionManager.shared.checkSpeechRecognitionPermission { speechGranted in
                DispatchQueue.main.async {
                    self.hasPermissionIssues = !(micGranted && accessibilityGranted && speechGranted)
                }
            }
        }
        
        // Check model status
        if let model = whisperManager.availableModels.first {
            hasModelIssues = !model.isAvailable && !whisperManager.isDownloading
        } else {
            hasModelIssues = true
        }
    }
    
    // MARK: - History Section
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            VStack(alignment: .leading, spacing: 4) {
                Text("My Activity")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
             }
            .padding(.bottom, 8)
            
            TranscriptionHistoryView()
                .settingsCardStyle()
        }
    }
    
    // MARK: - Model Settings Section
    private var modelSettingsSection: some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack(alignment: .bottom) {
                Text("Model Settings")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.bottom, 8)
            
            WhisperModelSelectionView(
                showTitle: false,
                showDescription: true
            )
            .settingsCardStyle()
        }
    }
    
    // MARK: - Hotkeys Section
    private var hotkeysSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Hotkeys")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Configure your keyboard shortcuts")
                    .font(.subheadline)
                    .foregroundColor(ThemeColors.secondaryText)
            }
            .padding(.bottom, 8)
            
            HotKeysView()
                .settingsCardStyle()
        }
    }
    
    // MARK: - Text Replacements Section
    private var magicActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Magic Actions")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Replace specific text with your preferred alternatives, including name variations")
                    .font(.subheadline)
                    .foregroundColor(ThemeColors.secondaryText)
            }
            .padding(.bottom, 8)
            
            MagicActionsView()
                .settingsCardStyle()
        }
    }
    
    // MARK: - Transcribe Section
    private var transcribeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            TranscribeFileView()
                .settingsCardStyle()
        }
    }
    
    // MARK: - App Settings Section
    private var appSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            VStack(alignment: .leading, spacing: 4) {
                Text("App Settings")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Configure general application settings")
                    .font(.subheadline)
                    .foregroundColor(ThemeColors.secondaryText)
            }
            .padding(.bottom, 8)
            
            AppSetupView()
                .settingsCardStyle()
        }
    }
    
    // MARK: - Integrations Section
    private var integrationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            WebhookSettingsView()
                .settingsCardStyle()
        }
    }
    
    // MARK: - Support Section
    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            Text("Support & Feedback")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .padding(.bottom, 8)
            
            SupportView()
                .settingsCardStyle()
        }
    }
    
    #if DEVELOPMENT
    // MARK: - Developer Section
    private var developerSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Section Header
            Text("Developer Settings")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Debug options for development")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Onboarding Settings
            VStack(alignment: .leading, spacing: 16) {
                Text("Onboarding")
                    .font(.headline)
                
                HStack {
                    Text("Onboarding Status")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(UserDefaults.standard.hasCompletedOnboarding ? "Completed" : "Not Completed")
                        .foregroundColor(UserDefaults.standard.hasCompletedOnboarding ? .green : .orange)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Current Step")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(UserDefaults.standard.integer(forKey: "currentOnboardingStep"))")
                        .fontWeight(.medium)
                }
                
                Divider()
                
                Button(action: {
                    UserDefaults.standard.hasCompletedOnboarding = false
                    UserDefaults.standard.set(1, forKey: "currentOnboardingStep")
                    
                    // Restart the app
                    let task = Process()
                    task.launchPath = "/usr/bin/open"
                    task.arguments = ["-n", Bundle.main.bundlePath]
                    task.launch()
                    
                    // Terminate current instance
                    NSApplication.shared.terminate(nil)
                }) {
                    Label("Reset Onboarding", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button(action: {
                    UserDefaults.standard.hasCompletedOnboarding = true
                }) {
                    Label("Mark Onboarding Complete", systemImage: "checkmark.circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button(action: {
                    // Reset the hotkey test completion state
                    UserDefaults.standard.set(false, forKey: "fnKeySetupComplete")
                    UserDefaults.standard.synchronize()
                }) {
                    Label("Reset Hotkey Test", systemImage: "keyboard.badge.ellipsis")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            
            Spacer()
        }
    }
    #endif
}

// Preview
struct UnifiedSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        UnifiedSettingsView()
            .environmentObject(AudioManager())
    }
}