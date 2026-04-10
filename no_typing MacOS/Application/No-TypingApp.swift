import SwiftUI

#if DEVELOPMENT
import Foundation // This import is not necessary if you're not using any Foundation types directly
#endif

// Add at the top of the file, outside the main app struct
extension View {
    func logView(_ message: String) -> some View {
        print("📱 APP VIEW: \(message)")
        return self
    }
}

// Add a logging utility
private func log(_ message: String) {
    print("📱 APP: \(message)")
}

// Add before the main app struct
@MainActor
private final class InitializationManager: ObservableObject {
    @Published private(set) var isInitialized = false
    
    func markAsInitialized() {
        isInitialized = true
    }
}

// MARK: - App State Management

@MainActor
class AppContentManager: ObservableObject {
    // Core managers for the application
    let windowManager: WindowManager
    
    // macOS-specific controllers
    #if os(macOS)
    let statusBarController: StatusBarController
    let hotkeyManager: GlobalHotkeyManager
    let audioManager: AudioManager
    #endif
    
    init() {
        // 1. First, handle any first-launch/reset logic BEFORE touching any managers
        AppContentManager.handleSetup()
        
        // 2. Initialize WindowManager first as other managers depend on it
        let winManager = WindowManager()
        self.windowManager = winManager
        
        // 3. Initialize macOS specific managers in order
        #if os(macOS)
        let audio = AudioManager()
        let status = StatusBarController(audioManager: audio)
        let hotkey = GlobalHotkeyManager(
            windowManager: winManager,
            statusBarController: status,
            audioManager: audio
        )
        
        self.audioManager = audio
        self.statusBarController = status
        self.hotkeyManager = hotkey
        #endif
    }
    
    private static func handleSetup() {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] [AppContentManager] Checking initial application state")
        
        // Handle fresh install simulation
        if UserDefaults.standard.bool(forKey: "simulateFirstLaunch") {
            print("[\(timestamp)] [AppContentManager] 🚀 Simulating fresh install - wiping all settings")
            let bundleId = Bundle.main.bundleIdentifier!
            
            // Clear UserDefaults
            UserDefaults.standard.removePersistentDomain(forName: bundleId)
            UserDefaults.standard.synchronize()
            
            // Clear application data
            if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let appFolder = appSupport.appendingPathComponent(bundleId)
                try? FileManager.default.removeItem(at: appFolder)
            }
            
            // Clear Keychain
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: bundleId
            ]
            SecItemDelete(query as CFDictionary)
            
            // Ensure default values for settings
            UserDefaults.standard.set(false, forKey: "streamingModeEnabled")
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
            UserDefaults.standard.set(true, forKey: "showOnboardingInDevMode")
            
            // Ensure the flag is disabled after the simulation runs once
            UserDefaults.standard.set(false, forKey: "simulateFirstLaunch")
        }
        
        // Standard setup that runs every time
        if UserDefaults.standard.object(forKey: "hasCompletedOnboarding") == nil {
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        }
    }
}


// Main entry point for the ThinkingAloud application
@main
struct ThinkingAloudApp: App {
    // Use the appropriate application delegate based on the platform
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #else
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    
    // StateObject to ensure core managers live for the entire app lifecycle
    @StateObject private var contentManager = AppContentManager()
    
    // Development mode settings
    #if DEVELOPMENT
    @AppStorage("devModeEnabled") private var devModeEnabled = false
    @AppStorage("showOnboardingInDevMode") private var showOnboardingInDevMode = false
    #endif

    // Replace the isInitialized state with a StateObject
    @StateObject private var initManager = InitializationManager()

    // Initialize the application and its core components
    init() {
        // Logging moved to Manager for better ordering
    }
    
    private func waitForInitialization() async {
        // Wait for WhisperManager to be ready
        await WhisperManager.shared.waitUntilReady()
        
        // Wait for audio engine to be ready
        #if os(macOS)
        await contentManager.audioManager.waitUntilReady()
        
        // Add a final check of the hotkey system
        let manager = contentManager.hotkeyManager // Capture the reference
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            // Reset the event tap to ensure clean state after initialization
            manager.resetEventTap()
        }
        #endif
        
        // Mark initialization as complete
        await initManager.markAsInitialized()
    }

    // MARK: - Default Settings
    
    private func ensureDefaultSettings() {
        // Set default value for streaming mode if it doesn't exist (block mode by default)
        if !UserDefaults.standard.contains(key: "streamingModeEnabled") {
            UserDefaults.standard.set(false, forKey: "streamingModeEnabled")
        }
    }

    // Define the app's user interface and behavior
    var body: some Scene {
        #if os(macOS)
        // On macOS, we only want menu bar functionality, no main window
        Settings {
            EmptyView()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1, height: 1)
        .windowStyle(.hiddenTitleBar)
        .commands {
            // Remove default menu items we don't want
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .saveItem) { }
            CommandGroup(replacing: .undoRedo) { }
            CommandGroup(replacing: .pasteboard) { }
        }
        #else
        WindowGroup {
            Group {
                if !initManager.isInitialized {
                    InitializationLoadingView()
                } else {
                    #if DEVELOPMENT
                    if devModeEnabled && showOnboardingInDevMode {
                        OnboardingView()
                            .overlay(DevModeOverlay(showControls: true), alignment: .topTrailing)
                            .logView("Showing OnboardingView (Dev Mode)")
                    } else if !UserDefaults.standard.hasCompletedOnboarding {
                        // First-time users always see OnboardingView
                        OnboardingView()
                            .overlay(DevModeOverlay(showControls: false), alignment: .topTrailing)
                            .logView("Showing OnboardingView (First-time User)")
                    } else {
                        // Show ContentView
                        ContentView()
                            .environmentObject(contentManager.windowManager)
                            .onAppear {
                                log("ContentView appeared")
                                requestMicrophonePermission()
                            }
                            .logView("Showing ContentView")
                    }
                    #else
                    if !UserDefaults.standard.hasCompletedOnboarding {
                        OnboardingView()
                    } else {
                        // Show ContentView
                        ContentView()
                            .environmentObject(contentManager.windowManager)
                            .onAppear {
                                requestMicrophonePermission()
                            }
                    }
                    #endif
                }
            }
            .frame(minWidth: AppConfig.WindowDimensions.minWidth, 
                   idealWidth: AppConfig.WindowDimensions.idealWidth, 
                   maxWidth: AppConfig.WindowDimensions.maxWidth,
                   minHeight: AppConfig.WindowDimensions.minHeight, 
                   idealHeight: AppConfig.WindowDimensions.idealHeight, 
                   maxHeight: AppConfig.WindowDimensions.maxHeight)
            .onAppear {
                log("Main window appeared")
                
                // Start initialization process
                Task {
                    await waitForInitialization()
                }
            }
        }
        .handlesExternalEvents(matching: [])
        #endif
    }
    
    // MARK: - Permission Handling
    
    /// Requests microphone permission using the PermissionManager.
    private func requestMicrophonePermission() {
        log("Checking microphone permission")
        PermissionManager.shared.checkMicrophonePermission { granted in
            if !granted {
                // Handle the case where microphone permission is denied
                // You might show an alert or update the UI accordingly
                print("Microphone permission was not granted.")
            } else {
                print("Microphone permission granted.")
            }
            log(granted ? "✅ Microphone permission granted" : "❌ Microphone permission denied")
        }
    }
    // Add this helper function
    private func clearKeychain(for bundleId: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: bundleId
        ]
        SecItemDelete(query as CFDictionary)
    }
}
