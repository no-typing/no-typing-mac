import Foundation
import Combine
import AppKit

class WatchFolderManager: ObservableObject {
    static let shared = WatchFolderManager()
    
    @Published var isWatching: Bool = false
    @Published var watchFolderPath: String? {
        didSet {
            UserDefaults.standard.set(watchFolderPath, forKey: "NoTypingWatchFolderPath")
            if let path = watchFolderPath {
                startWatching(url: URL(fileURLWithPath: path))
            } else {
                stopWatching()
            }
        }
    }
    
    private var folderMonitorSource: DispatchSourceFileSystemObject?
    private let queue = DispatchQueue(label: "com.no_typing.watchfolder", qos: .background)
    
    // Support file types
    private let supportedExtensions = ["mp3", "wav", "m4a", "ogg", "opus", "mov", "mp4"]
    private var processedFiles: Set<String> = []
    
    private init() {
        if let savedPath = UserDefaults.standard.string(forKey: "NoTypingWatchFolderPath") {
            let url = URL(fileURLWithPath: savedPath)
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                self.watchFolderPath = savedPath
                self.startWatching(url: url)
            } else {
                // Path no longer valid
                self.watchFolderPath = nil
            }
        }
    }
    
    deinit {
        stopWatching()
    }
    
    func selectFolder() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        openPanel.prompt = "Select Watch Folder"
        openPanel.message = "Choose a folder to automatically transcribe audio files added to it."
        
        openPanel.begin { [weak self] (response: NSApplication.ModalResponse) in
            if response == .OK, let url = openPanel.url {
                // Ensure we save a clean path
                DispatchQueue.main.async {
                    self?.watchFolderPath = url.path
                }
            }
        }
    }
    
    private func startWatching(url: URL) {
        stopWatching() // Ensure no previous monitors are running
        
        // Check if directory exists
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            print("❌ Invalid Watch Folder Path: \(url.path)")
            DispatchQueue.main.async { self.isWatching = false }
            return
        }
        
        // Open file descriptor for the folder
        let folderDescriptor = open(url.path, O_EVTONLY)
        guard folderDescriptor != -1 else {
            print("❌ Failed to open file descriptor for Watch Folder.")
            DispatchQueue.main.async { self.isWatching = false }
            return
        }
        
        // Create the Dispatch Source
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: folderDescriptor,
            eventMask: .write,
            queue: queue
        )
        
        source.setEventHandler { [weak self] in
            self?.checkForNewFiles(in: url)
        }
        
        source.setCancelHandler {
            close(folderDescriptor)
        }
        
        folderMonitorSource = source
        source.resume()
        
        DispatchQueue.main.async { self.isWatching = true }
        print("👀 Started watching folder: \(url.path)")
        
        // Initial scan
        checkForNewFiles(in: url)
    }
    
    func stopWatching() {
        if let source = folderMonitorSource {
            source.cancel()
            folderMonitorSource = nil
            DispatchQueue.main.async { self.isWatching = false }
            print("🛑 Stopped watching folder.")
        }
    }
    
    private func checkForNewFiles(in folderURL: URL) {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            
            for fileURL in fileURLs {
                let isSupported = supportedExtensions.contains(fileURL.pathExtension.lowercased())
                let isProcessed = processedFiles.contains(fileURL.lastPathComponent)
                
                if isSupported && !isProcessed {
                    print("🆕 Discovered new media file in Watch Folder: \(fileURL.lastPathComponent)")
                    processedFiles.insert(fileURL.lastPathComponent)
                    
                    // Enqueue to FileTranscriptionManager
                    DispatchQueue.main.async {
                        // If it's already transcribing, queueing logic should exist, but currently FileTranscriptionManager drops tasks if isTranscribing == true.
                        // We will delay the execution slightly if busy to simulate a rudimentary queue.
                        self.enqueueTranscription(for: fileURL)
                    }
                }
            }
        } catch {
            print("❌ Error reading Watch Folder contents: \(error.localizedDescription)")
        }
    }
    
    private func enqueueTranscription(for url: URL) {
        // Use FileTranscriptionManager's built-in batch queue
        FileTranscriptionManager.shared.queueFiles([url])
    }
}
