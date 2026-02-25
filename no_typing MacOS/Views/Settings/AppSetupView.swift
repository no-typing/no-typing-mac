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
    
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Permission Configuration Section
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield")
                        .font(.title3)
                        .foregroundColor(.white)
                    Text("Permission Configuration")
                        .font(.title3)
                        .foregroundColor(.white)
                }
                
                Text("No-Typing needs microphone, accessibility, and speech detection permissions to function properly.")
                    .font(.body)
                    .foregroundColor(ThemeColors.secondaryText)
                
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
            
            
            // Startup Configuration Section
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "power")
                        .font(.title3)
                        .foregroundColor(.white)
                    Text("Startup Configuration")
                        .font(.title3)
                        .foregroundColor(.white)
                }
                
                Text("Configure how No-Typing behaves when your Mac starts up.")
                    .font(.body)
                    .foregroundColor(ThemeColors.secondaryText)
                
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
            
            // Sound Settings Section
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "speaker.wave.3")
                        .font(.title3)
                        .foregroundColor(.white)
                    Text("Sound Settings")
                        .font(.title3)
                        .foregroundColor(.white)
                }
                
                Text("Configure sound effects for the HUD display.")
                    .font(.body)
                    .foregroundColor(ThemeColors.secondaryText)
                
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
            

        }
        // Use transparent background since this view is already wrapped in .settingsCardStyle() by the parent
        .background(Color.clear)
        .onAppear {
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