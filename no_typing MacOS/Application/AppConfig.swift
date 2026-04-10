import Foundation

enum AppConfig {
    // Base URLs
//    #if DEVELOPMENT
//    static let BACKEND_API_URL = ""
//    static let API_KEY = ""
//    static let STT_WEBSOCKET_URL = ""
//    #else
    static let BACKEND_API_URL = ""
    static let API_KEY = ""
    static let STT_WEBSOCKET_URL = ""
//    #endif

    // You can also add computed properties that use the DEVELOPMENT flag
    static var isDebugMode: Bool {
        #if DEVELOPMENT
        return true
        #else
        return false
        #endif
    }
    
    // Window dimensions
    struct WindowDimensions {
        static let minWidth: CGFloat = 950
        static let idealWidth: CGFloat = 950
        static let maxWidth: CGFloat = CGFloat.infinity
        
        static let minHeight: CGFloat = 650
        static let idealHeight: CGFloat = 700
        static let maxHeight: CGFloat = CGFloat.infinity
        
        // Initial window size (can be larger than min, smaller than max)
        static let initialWidth: CGFloat = 950
        static let initialHeight: CGFloat = 700
    }
}
