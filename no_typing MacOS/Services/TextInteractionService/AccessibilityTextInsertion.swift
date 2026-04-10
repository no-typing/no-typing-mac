import Foundation
import AppKit
import ApplicationServices

/// Responsible for inserting text via accessibility APIs
class AccessibilityTextInsertion {
    
    private let directTextInsertion: DirectTextInsertion
    private let clipboardTextInsertion: ClipboardTextInsertion
    
    // Applications known to block accessibility or behave better with clipboard
    private let knownRestrictedApps = ["Cursor", "CursorEditor", "Mail", "Notes"]
    
    init(directTextInsertion: DirectTextInsertion, clipboardTextInsertion: ClipboardTextInsertion) {
        self.directTextInsertion = directTextInsertion
        self.clipboardTextInsertion = clipboardTextInsertion
    }
    
    /// Gets the current system-wide focused UI element
    func getSystemFocusedElement() -> AXUIElement? {
        guard checkAccessibilityPermissions(shouldPrompt: false) else { return nil }
        
        let systemElement = AXUIElementCreateSystemWide()
        var appRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(systemElement, kAXFocusedApplicationAttribute as CFString, &appRef)
        
        guard result == .success, let appRef = appRef else { return nil }
        
        let appElement = appRef as! AXUIElement
        var focusedElementRef: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElementRef)
        
        guard focusedResult == .success, let focusedElementRef = focusedElementRef else {
            return appElement // Fallback to app element
        }
        
        return (focusedElementRef as! AXUIElement)
    }
    
    /// Gets the PID of the currently focused application
    func getCurrentFocusedPID() -> pid_t? {
        guard let systemElement = AXUIElementCreateSystemWide() as AXUIElement?,
              checkAccessibilityPermissions(shouldPrompt: false) else { return nil }
        
        var appRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(systemElement, kAXFocusedApplicationAttribute as CFString, &appRef)
        
        guard result == .success, let appRef = appRef else { return nil }
        
        let appElement = appRef as! AXUIElement
        var pid: pid_t = 0
        AXUIElementGetPid(appElement, &pid)
        return pid != 0 ? pid : nil
    }

    /// Checks if the app has accessibility permissions
    func checkAccessibilityPermissions(shouldPrompt: Bool = true) -> Bool {
        if !AXIsProcessTrusted() {
            if shouldPrompt {
                let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
                AXIsProcessTrustedWithOptions(options)
            }
            return false
        }
        return true
    }
    
    /// Inserts text using the accessibility API (with clipboard fallback)
    func insertText(
        _ text: String,
        isTemporary: Bool = false,
        finalizedText: String,
        streamingInsertedText: String,
        onFinalizedTextUpdated: @escaping (String) -> Void,
        onStreamingStateUpdated: @escaping (Int, Int) -> Void
    ) -> Bool {
        print("🔤 Accessibility: Inserting text via clipboard fallback")
        
        let formattedText = formatTextWithCapitalization(text, isTemp: isTemporary, finalizedText: finalizedText)
        
        if !isTemporary {
            var updatedFinalizedText = finalizedText
            if finalizedText.isEmpty {
                updatedFinalizedText = formattedText
            } else {
                updatedFinalizedText += " " + formattedText
            }
            onFinalizedTextUpdated(updatedFinalizedText)
        }
        
        return clipboardTextInsertion.insertText(formattedText, preserveClipboard: true)
    }
    
    /// Replaces temporary text with finalized text
    func replaceTemporaryText(
        _ temporaryText: String,
        with finalText: String,
        finalizedText: String,
        onFinalizedTextUpdated: @escaping (String) -> Void
    ) -> Bool {
        print("🔤 Accessibility: Replacing text via clipboard")
        
        let formattedText = formatTextWithCapitalization(finalText, isTemp: false, finalizedText: finalizedText)
        
        // Update finalized text tracking
        var updatedFinalizedText = finalizedText
        if finalizedText.isEmpty {
            updatedFinalizedText = formattedText
        } else {
            updatedFinalizedText += " " + formattedText
        }
        onFinalizedTextUpdated(updatedFinalizedText)
        
        // Since we are using clipboard for everything now to avoid focus issues
        return clipboardTextInsertion.insertText(formattedText, preserveClipboard: true)
    }
    
    /// Helper to format text with appropriate capitalization
    private func formatTextWithCapitalization(_ text: String, isTemp: Bool, finalizedText: String = "") -> String {
        if isTemp || text.isEmpty { return text }
        
        let trimmedFinalText = finalizedText.trimmingCharacters(in: .whitespaces)
        let endsWithSentencePunctuation = trimmedFinalText.hasSuffix(".") || 
                                         trimmedFinalText.hasSuffix("!") || 
                                         trimmedFinalText.hasSuffix("?")
        
        let shouldCapitalize = trimmedFinalText.isEmpty || endsWithSentencePunctuation
        
        if shouldCapitalize {
            let firstChar = text.prefix(1).uppercased()
            let restOfText = text.dropFirst()
            return firstChar + restOfText
        } else {
            // Check if first char is already capitalized (like "I")
            if text.prefix(1).uppercased() == text.prefix(1) {
                // Keep it
                return text
            }
            return text
        }
    }
}