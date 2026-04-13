import SwiftUI
import AVFoundation
import Speech
#if os(macOS)
import AppKit
import ServiceManagement
#endif

struct AppSetupView: View {
    @State private var microphonePermissionGranted = false
    @State private var accessibilityPermissionGranted = false
    @State private var speechRecognitionPermissionGranted = false
    @State private var showAccessibilityPrompt = false
    @State private var navigatingToSettingsForAccessibility = false
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("enableTranscriptionCleaning") private var enableTranscriptionCleaning = true
    @ObservedObject private var soundEffects = HUDSoundEffects.shared
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var audioManager: AudioManager
    @StateObject private var watchFolderManager = WatchFolderManager.shared
    @StateObject private var webhookManager = WebhookManager.shared
    @State private var voiceWebhookEndpointId: String = UserDefaults.standard.string(forKey: "voiceWebhookEndpointId") ?? ""
    
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Audio Input Source Section
            SettingsSectionView(
                icon: "mic.fill",
                title: "Audio Input Source",
                description: "Select whether to record from your microphone or capture all system audio."
            ) {
                HStack {
                    Spacer()
                    Picker("Source", selection: $audioManager.inputSource) {
                        ForEach(AudioInputSource.allCases) { source in
                            Text(source.rawValue).tag(source)
                        }
                    }
                    .frame(width: 220)
                }
            }
            
            SectionDivider()
            
            // Permission Configuration Section
            SettingsSectionView(
                icon: "lock.shield",
                title: "Permission Configuration",
                description: "No-Typing needs microphone, accessibility, and speech detection permissions to function properly."
            ) {
                
                VStack(alignment: .leading, spacing: 12) {
                    if microphonePermissionGranted {
                        StatusRow(title: "Mic Permission", status: true)
                    } else {
                        StatusActionRow(
                            title: "Mic Permission",
                            actionTitle: "Give Access",
                            action: requestMicrophonePermission
                        )
                    }
                    
                    Divider()
                    
                    if accessibilityPermissionGranted {
                        StatusRow(title: "Accessibility Permission", status: true)
                    } else {
                        StatusActionRow(
                            title: "Accessibility Permission",
                            actionTitle: "Give Access",
                            action: requestAccessibilityPermission
                        )
                    }

                    Divider()
                    
                    if speechRecognitionPermissionGranted {
                        StatusRow(title: "Speech Detection", status: true)
                    } else {
                        StatusActionRow(
                            title: "Speech Detection",
                            actionTitle: "Give Access",
                            action: requestSpeechRecognitionPermission
                        )
                    }
                }
                .padding(8)
            }
            
            // Troubleshooting Notice
            if !allPermissionsGranted {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Permission Sync Error?")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.orange)
                        
                        Text("If settings show access but the app says denied, your Mac's privacy cache might be stale. Try running these commands in Terminal and then restart the app:")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.8))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("tccutil reset Microphone com.no-typing")
                            Text("tccutil reset SpeechRecognition com.no-typing")
                        }
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.orange.opacity(0.9))
                        .padding(8)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(6)
                        .textSelection(.enabled)
                    }
                }
                .padding(12)
                .background(Color.orange.opacity(0.05))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.3), lineWidth: 1))
            }
            
            Divider().padding(.vertical, 8)
            
            // Startup Configuration Section
            SettingsSectionView(
                icon: "power",
                title: "Startup Configuration",
                description: "Configure how No-Typing behaves when your Mac starts up."
            ) {
                
                VStack(alignment: .leading) {
                    SettingsToggleRow(
                        icon: "arrow.right.circle",
                        title: "Launch at Login",
                        isOn: $launchAtLogin,
                        iconGradient: LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .onChange(of: launchAtLogin) { newValue in
                        toggleLaunchAtLogin(newValue)
                    }
                }
                .padding(8)
            }
            
            Divider().padding(.vertical, 8)
            
            // Watch Folder Section
            SettingsSectionView(
                icon: "folder.badge.gearshape",
                title: "Watch Folder",
                description: "Automatically transcribe audio files dropped into this folder."
            ) {
                
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Target Directory")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(watchFolderManager.watchFolderPath ?? "None Selected")
                                .font(.caption)
                                .foregroundColor(ThemeColors.secondaryText)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        
                        Spacer()
                        
                        SecondaryButton(
                            title: watchFolderManager.watchFolderPath == nil ? "Select Folder" : "Change Folder",
                            action: { watchFolderManager.selectFolder() }
                        )
                    }
                    
                    if watchFolderManager.watchFolderPath != nil {
                        SettingsToggleRow(
                            icon: "eye",
                            title: "Enable Watch Folder",
                            isOn: $watchFolderManager.isWatching,
                            iconGradient: LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    }
                }
                .padding(8)
            }
            
            Divider().padding(.vertical, 8)
            
            // Sound Settings Section
            SettingsSectionView(
                icon: "speaker.wave.3",
                title: "Sound Settings",
                description: "Configure sound effects for the HUD display."
            ) {
                
                VStack(alignment: .leading) {
                    SettingsToggleRow(
                        icon: "speaker",
                        title: "Enable Sound Effects",
                        isOn: $soundEffects.soundsEnabled,
                        iconGradient: LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                }
                .padding(8)
            }
            
            Divider().padding(.vertical, 8)
            
            // Voice Webhook Section
            SettingsSectionView(
                icon: "antenna.radiowaves.left.and.right",
                title: "Dictation Webhook",
                description: "Forward dictation results to the selected webhook endpoint."
            ) {
                HStack {
                    Picker("Webhook", selection: Binding(
                        get: { voiceWebhookEndpointId },
                        set: { newValue in
                            voiceWebhookEndpointId = newValue
                            UserDefaults.standard.set(newValue, forKey: "voiceWebhookEndpointId")
                        }
                    )) {
                        Text("None").tag("")
                        ForEach(webhookManager.endpoints) { endpoint in
                            Text(endpoint.name).tag(endpoint.id.uuidString)
                        }
                    }
                    .frame(width: 220)
                }
            }

        }
        // Use transparent background since this view is already wrapped in .settingsCardStyle() by the parent
        .background(Color.clear)
        .onAppear {
            checkPermissions()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            print("🔄 App became active, refreshing permissions...")
            checkPermissions()
        }
        .alert(isPresented: $showAccessibilityPrompt) {
            Alert(
                title: Text("Accessibility Permission"),
                message: Text("Did you grant accessibility permission in System Preferences?"),
                primaryButton: .default(Text("Yes")) {
                    self.accessibilityPermissionGranted = true
                },
                secondaryButton: .cancel(Text("No"))
            )
        }
    }
    
    private func checkPermissions() {
        // Use PermissionManager for all permission checks
        PermissionManager.shared.checkMicrophonePermission { granted in
            microphonePermissionGranted = granted
        }
        
        accessibilityPermissionGranted = PermissionManager.shared.checkAccessibilityPermission()
        
        PermissionManager.shared.checkSpeechRecognitionPermission { granted in
            speechRecognitionPermissionGranted = granted
        }
    }
    
    private func requestMicrophonePermission() {
        PermissionManager.shared.requestMicrophonePermission { granted in
            DispatchQueue.main.async {
                self.microphonePermissionGranted = granted
            }
        }
    }
    
    private func requestAccessibilityPermission() {
        PermissionManager.shared.requestAccessibilityPermissionWithPrompt { granted in
            DispatchQueue.main.async {
                self.accessibilityPermissionGranted = granted
                self.navigatingToSettingsForAccessibility = !granted
            }
        }
    }
    
    private func requestSpeechRecognitionPermission() {
        PermissionManager.shared.requestSpeechRecognitionPermission { granted in
            DispatchQueue.main.async {
                self.speechRecognitionPermissionGranted = granted
            }
        }
    }
    
    private func toggleLaunchAtLogin(_ isOn: Bool) {
        #if os(macOS)
        do {
            if isOn {
                try SMAppService.mainApp.register()
                print("Launch at Login enabled")
            } else {
                try SMAppService.mainApp.unregister()
                print("Launch at Login disabled")
            }
        } catch {
            print("Failed to \(isOn ? "enable" : "disable") launch at login: \(error.localizedDescription)")
            
            // Revert the toggle if setting fails
            DispatchQueue.main.async {
                launchAtLogin = !isOn
            }
            
            let alert = NSAlert()
            alert.messageText = "Unable to Change Launch Settings"
            alert.informativeText = "Could not modify launch at login preference. Please check your system settings."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
        #endif
    }
    

    
    // Add computed property to check if all permissions are granted
    private var allPermissionsGranted: Bool {
        microphonePermissionGranted && 
        accessibilityPermissionGranted && 
        speechRecognitionPermissionGranted
    }
}