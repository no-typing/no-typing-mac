import Foundation
import SwiftUI
import Cocoa

// Add any custom imports required for HUD components
// The HUDMainController class should be available through the main module imports

class AudioHUDService {
    // Shared singleton instance
    static let shared = AudioHUDService()
    
    // Main controller for the HUD window
    private var notchIndicatorController: HUDMainController?
    
    // Device name notification window
    private var deviceNameWindow: DeviceNameWindowController?
    
    // Status/Action notification window
    private var statusNotificationWindow: StatusNotificationWindowController?
    
    // Flag to prevent multiple simultaneous cleanup operations
    private var isHUDCleanupInProgress = false
    
    // Work item for scheduled cleanup operations
    private var cleanupWorkItem: DispatchWorkItem?
    
    
    // Initialize
    init() {
    }
    
    // MARK: - Public Methods
    
    /// Shows the recording HUD
    /// - Parameter audioManager: Reference to the AudioManager for HUD callbacks
    public func showHUD(audioManager: AudioManager) {
        
        // Cancel any pending cleanup
        cleanupWorkItem?.cancel()
        cleanupWorkItem = nil
        isHUDCleanupInProgress = false
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Create new HUD if needed
            if self.notchIndicatorController == nil {
                self.notchIndicatorController = HUDMainController(
                    audioManager: audioManager
                )
                self.notchIndicatorController?.showAnimated()
                print("HUD controller shown")
            }
        }
    }
    
    /// Hides the recording HUD with proper cleanup
    public func hideHUD() {
        print("AudioHUDService: hideHUD called")
        
        // Cancel any pending cleanup
        cleanupWorkItem?.cancel()
        
        // Create new cleanup work item
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self,
                  !self.isHUDCleanupInProgress else { return }
            
            self.isHUDCleanupInProgress = true
            
            // Perform cleanup on main thread
            DispatchQueue.main.async {
                if let controller = self.notchIndicatorController {
                    controller.hideAnimated()
                    // Don't call close() immediately - let hideAnimated handle it
                    self.notchIndicatorController = nil
                    print("HUD controller released")
                }
                self.isHUDCleanupInProgress = false
            }
        }
        
        // Store and execute the work item
        cleanupWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
    }
    
    /// Shows device change notification above the HUD
    public func showDeviceChangeNotification(deviceName: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Hide any existing device name window
            self.deviceNameWindow?.hideAnimated()
            self.deviceNameWindow = nil
            
            // Get parent window for positioning
            let parentWindow = self.notchIndicatorController?.window
            
            // Create and show new device name window
            self.deviceNameWindow = DeviceNameWindowController(
                deviceName: deviceName,
                parentWindow: parentWindow
            )
        }
    }
    
    
    /// Shows a status/action notification (e.g., Focus Lost, Clipboard copied)
    public func showStatusNotification(title: String, message: String, icon: String, appIcon: NSImage? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Hide any existing status window
            self.statusNotificationWindow?.hideAnimated()
            self.statusNotificationWindow = nil
            
            // Get parent window for positioning
            let parentWindow = self.notchIndicatorController?.window
            
            // Create and show new status window
            self.statusNotificationWindow = StatusNotificationWindowController(
                title: title,
                message: message,
                icon: icon,
                appIcon: appIcon,
                parentWindow: parentWindow
            )
        }
    }
    
    // MARK: - Cleanup and Deinitialization
    
    /// Performs full cleanup of all HUD resources
    public func cleanup() {
        cleanupWorkItem?.cancel()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let controller = self.notchIndicatorController {
                controller.close()
                self.notchIndicatorController = nil
            }
            
            if let deviceWindow = self.deviceNameWindow {
                deviceWindow.hideAnimated()
                self.deviceNameWindow = nil
            }
            
            if let statusWindow = self.statusNotificationWindow {
                statusWindow.hideAnimated()
                self.statusNotificationWindow = nil
            }
            
            self.isHUDCleanupInProgress = false
        }
    }
    
    deinit {
        cleanup()
    }
} 
