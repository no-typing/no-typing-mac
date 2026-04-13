/// PermissionManager is a singleton service that handles all system-level permission requests and checks.
import AVFoundation
import ApplicationServices
import Speech

#if os(macOS)
import AppKit
#endif

class PermissionManager {
    static let shared = PermissionManager()
    
    private init() {
        print("🛡️ PermissionManager initialized for bundle: \(Bundle.main.bundleIdentifier ?? "unknown")")
    }
    
    // MARK: - Microphone Permission
    
    func checkMicrophonePermission(completion: @escaping (Bool) -> Void) {
        let permissionStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        print("🎤 DEBUG: Microphone status: \(permissionStatus.rawValue) (authorized = 3, denied = 1, restricted = 2, notDetermined = 0)")
        
        let granted = permissionStatus == .authorized
        DispatchQueue.main.async {
            completion(granted)
        }
    }
    
    func checkMicrophonePermissionSync() -> Bool {
        let permissionStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        return permissionStatus == .authorized
    }
    
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        let permissionStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        print("🎤 Requesting microphone permission for \(Bundle.main.bundleIdentifier ?? "unknown"). Current: \(permissionStatus.rawValue)")
        
        switch permissionStatus {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                print("🎤 Microphone access granted: \(granted)")
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .authorized:
            DispatchQueue.main.async {
                completion(true)
            }
        case .denied, .restricted:
            print("🎤 Microphone permission previously denied, opening System Settings...")
            DispatchQueue.main.async {
                self.openSystemPreferencesPrivacyMicrophone()
                completion(false)
            }
        @unknown default:
            completion(false)
        }
    }
    
    private func forceRegisterMicrophone() {
        print("🎤 DEBUG: Forcing microphone registration via AVCaptureSession...")
        let session = AVCaptureSession()
        guard let device = AVCaptureDevice.default(for: .audio) else { return }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
                session.startRunning()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    session.stopRunning()
                }
            }
        } catch {
            print("🎤 DEBUG: Force registration capture failed: \(error)")
        }
    }
    
    // MARK: - Speech Recognition Permission
    
    func checkSpeechRecognitionPermission(completion: @escaping (Bool) -> Void) {
        let status = SFSpeechRecognizer.authorizationStatus()
        print("🗣️ DEBUG: Speech Recognition status: \(status.rawValue) (authorized = 3, denied = 1, restricted = 2, notDetermined = 0)")
        
        let locale = Locale.current
        let isAvailable = SFSpeechRecognizer(locale: locale) != nil
        print("🗣️ DEBUG: SFSpeechRecognizer is available for \(locale.identifier): \(isAvailable)")
        
        DispatchQueue.main.async {
            completion(status == .authorized)
        }
    }
    
    func checkSpeechRecognitionPermissionSync() -> Bool {
        return SFSpeechRecognizer.authorizationStatus() == .authorized
    }
    
    func requestSpeechRecognitionPermission(completion: @escaping (Bool) -> Void) {
        let status = SFSpeechRecognizer.authorizationStatus()
        print("🗣️ Current speech recognition status: \(status.rawValue) (authorized=3, denied=1, restricted=2, notDetermined=0)")
        
        switch status {
        case .notDetermined:
            SFSpeechRecognizer.requestAuthorization { authStatus in
                print("🗣️ Speech recognition authorization result: \(authStatus.rawValue)")
                DispatchQueue.main.async {
                    completion(authStatus == .authorized)
                }
            }
        case .authorized:
            DispatchQueue.main.async {
                completion(true)
            }
        case .denied, .restricted:
            print("🗣️ Speech recognition previously denied, opening System Settings...")
            DispatchQueue.main.async {
                self.openSystemPreferencesPrivacySpeech()
                completion(false)
            }
        @unknown default:
            completion(false)
        }
    }
    
    private func forceRegisterSpeech() {
        print("🗣️ DEBUG: Forcing speech recognition registration...")
        _ = SFSpeechRecognizer(locale: Locale.current)
    }
    
    // MARK: - Accessibility Permission
    
    func checkAccessibilityPermission() -> Bool {
        #if os(macOS)
        return AXIsProcessTrusted()
        #else
        return true
        #endif
    }
    
    func requestAccessibilityPermissionWithPrompt(completion: @escaping (Bool) -> Void) {
        print("🔑 Requesting accessibility permission...")
        
        #if os(macOS)
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        let _ = AXIsProcessTrustedWithOptions(options)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let newStatus = AXIsProcessTrusted()
            if !newStatus {
                self.openSystemPreferencesPrivacyAccessibility()
            }
            completion(newStatus)
        }
        #else
        DispatchQueue.main.async {
            completion(true)
        }
        #endif
    }
    
    // MARK: - System Preferences Helpers
    
    func openSystemPreferencesPrivacyMicrophone() {
        #if os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }
    
    func openSystemPreferencesPrivacySpeech() {
        #if os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }
    
    func openSystemPreferencesPrivacyAccessibility() {
        #if os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }
}
