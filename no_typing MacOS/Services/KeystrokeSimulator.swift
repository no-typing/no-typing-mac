import Foundation
import CoreGraphics

class KeystrokeSimulator {
    static let shared = KeystrokeSimulator()
    
    // Virtual KeyCodes (Carbon)
    private let kVK_Return: CGKeyCode = 0x24
    private let kVK_Tab: CGKeyCode = 0x30
    private let kVK_ANSI_Z: CGKeyCode = 0x06
    private let kVK_ANSI_A: CGKeyCode = 0x00
    private let kVK_Delete: CGKeyCode = 0x33
    
    private init() {}
    
    func execute(_ action: CommandAction) {
        print("⌨️ KeystrokeSimulator executing action: \(action.rawValue)")
        
        switch action {
        case .return:
            simulateKeyPress(keyCode: kVK_Return)
        case .tab:
            simulateKeyPress(keyCode: kVK_Tab)
        case .undo:
            simulateKeyPress(keyCode: kVK_ANSI_Z, flags: .maskCommand)
        case .newLine:
            simulateKeyPress(keyCode: kVK_Return, flags: .maskShift)
        case .selectAll:
            simulateKeyPress(keyCode: kVK_ANSI_A, flags: .maskCommand)
        case .clear:
            simulateKeyPress(keyCode: kVK_ANSI_A, flags: .maskCommand)
            usleep(50000) // 50ms delay
            simulateKeyPress(keyCode: kVK_Delete)
        }
    }
    
    private func simulateKeyPress(keyCode: CGKeyCode, flags: CGEventFlags? = nil) {
        let loc = CGEventTapLocation.cghidEventTap
        
        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            print("⚠️ KeystrokeSimulator: Failed to create CGEvent")
            return
        }
        
        if let flags = flags {
            keyDown.flags = flags
            keyUp.flags = flags
        }
        
        // Post events
        keyDown.post(tap: loc)
        
        // Short delay for reliability across different applications
        usleep(10000) // 10ms
        
        keyUp.post(tap: loc)
    }
}
