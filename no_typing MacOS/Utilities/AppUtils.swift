import Foundation
import AppKit

struct AppUtils {
    /// Resolves a human-readable application name from a bundle identifier.
    /// Falls back to "No-Typing" if resolution fails.
    static func getAppName(from bundleID: String?) -> String {
        guard let bundleID = bundleID else {
            return "No-Typing"
        }
        
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let appName = (try? appURL.resourceValues(forKeys: [.localizedNameKey]).localizedName) 
                ?? appURL.deletingPathExtension().lastPathComponent
            return appName
        }
        
        return bundleID // Fallback to bundle ID if URL can't be found
    }
}
