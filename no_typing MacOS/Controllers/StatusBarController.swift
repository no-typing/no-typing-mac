import SwiftUI
import AppKit
import Combine

class StatusBarController: NSObject, ObservableObject {
    private var statusBar: NSStatusBar?
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    
    @ObservedObject var audioManager: AudioManager
    
    private var settingsItem: NSMenuItem?
    private var settingsWindow: NSWindow?
    private var settingsWindowController: NSWindowController?
    private var cancellables = Set<AnyCancellable>()
    
    private var appDelegate: AppDelegate? {
        return NSApp.delegate as? AppDelegate
    }
    
    init(audioManager: AudioManager) {
        self.audioManager = audioManager
        super.init()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.setupStatusBar()
            
            // Listen for settings window requests
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.openSettings(_:)),
                name: NSNotification.Name("ShowSettingsWindow"),
                object: nil
            )
            
            self.audioManager.$isRecordingEnabled
                .receive(on: DispatchQueue.main)
                .sink { [weak self] isEnabled in
                    self?.updateIcon(isEnabled: isEnabled)
                }
                .store(in: &self.cancellables)
        }
    }
    
    private func setupStatusBar() {
        statusBar = NSStatusBar.system
        statusItem = statusBar?.statusItem(withLength: NSStatusItem.variableLength)
        menu = NSMenu()
        
        setupStatusBarButton()
        setupMenu()
    }
    
    private func setupStatusBarButton() {
        if let statusBarButton = statusItem?.button {
            // Load the enabled custom icon by default
            if let icon = NSImage(named: "StatusBarIconEnabled") {
                icon.isTemplate = true
                icon.size = NSSize(width: 16, height: 16)
                statusBarButton.image = icon
            }
            
            // Set action to directly open settings when clicked
            statusBarButton.action = #selector(openSettings(_:))
            statusBarButton.target = self
            
            // Enable right-click detection
            statusBarButton.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }
    
    private func updateIcon(isEnabled: Bool) {
        if let statusBarButton = statusItem?.button {
            if isEnabled {
                statusBarButton.contentTintColor = nil
                
                // Load the enabled icon
                if let originalIcon = NSImage(named: "StatusBarIconEnabled") {
                    originalIcon.isTemplate = true
                    originalIcon.size = NSSize(width: 16, height: 16)
                    statusBarButton.image = originalIcon
                }
            } else {
                statusBarButton.contentTintColor = nil
                
                // Load the disabled icon
                if let disabledIcon = NSImage(named: "StatusBarIconDisabled") {
                    disabledIcon.isTemplate = true
                    disabledIcon.size = NSSize(width: 16, height: 16)
                    statusBarButton.image = disabledIcon
                }
            }
        }
    }
    
    private func setupMenu() {
        // Remove menu setup - we're now opening settings directly on click
        statusItem?.menu = nil
    }
    
    
    @objc func openSettings(_ sender: Any?) {
        // Check if it's a right-click
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            // Show context menu on right-click
            showContextMenu()
            return
        }
        
        // Left-click - open settings
        // IMPORTANT: Activate app synchronously before any async work.
        // If deferred (e.g. via Task), the status bar click event completes first
        // and macOS deactivates the app, causing the window to flash and disappear.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        // Check if settings window already exists
        if let existingWindow = settingsWindow {
            // If window is minimized, deminiaturize it
            if existingWindow.isMiniaturized {
                existingWindow.deminiaturize(nil)
            }
            
            existingWindow.makeKeyAndOrderFront(nil)
            existingWindow.orderFrontRegardless()
            return
        }
        
        // Create new window only if it doesn't exist
        let windowManager = WindowManager()
        
        // Define a reactive wrapper view to handle internal navigation between Onboarding and Settings
        struct MainAppWindowView: View {
            @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false
            let windowManager: WindowManager
            let audioManager: AudioManager
            
            var body: some View {
                if hasCompletedOnboarding {
                    ContentView()
                        .environmentObject(windowManager)
                        .environmentObject(audioManager)
                } else {
                    OnboardingView()
                        .environmentObject(windowManager)
                        .environmentObject(audioManager)
                }
            }
        }
        
        let rootView = MainAppWindowView(
            windowManager: windowManager,
            audioManager: self.audioManager
        )
        
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = ""
        window.setContentSize(NSSize(width: AppConfig.WindowDimensions.initialWidth, 
                                   height: AppConfig.WindowDimensions.initialHeight))
        window.minSize = NSSize(width: AppConfig.WindowDimensions.minWidth, 
                              height: AppConfig.WindowDimensions.minHeight)
        window.center()
        
        // Configure window style
        window.backgroundColor = NSColor.windowBackgroundColor
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        
        // Set delegate to handle window closing
        window.delegate = self
        
        // Store reference to the window
        settingsWindow = window
        
        // Create window controller to keep window alive
        let windowController = NSWindowController(window: window)
        settingsWindowController = windowController
        
        windowController.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
    
    private func showContextMenu() {
        let menu = NSMenu()
        
        // Add Quit menu item
        let quitItem = NSMenuItem(title: "Quit No-Typing", action: #selector(quitApp), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)
        
        // Show the menu
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        
        // Remove the menu after showing to restore normal left-click behavior
        DispatchQueue.main.async { [weak self] in
            self?.statusItem?.menu = nil
        }
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - NSWindowDelegate
extension StatusBarController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // Clear the window reference when it closes
        if notification.object as? NSWindow === settingsWindow {
            settingsWindow = nil
            settingsWindowController = nil
            
            // Hide from dock
            NSApp.setActivationPolicy(.accessory)
        }
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Allow the window to close
        return true
    }
}
