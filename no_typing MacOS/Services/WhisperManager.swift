//
//  WhisperManager.swift
//  no_typing MacOS
//
//  Created by Liam Alizadeh on 10/18/24.
//

/// WhisperManager handles all aspects of the Whisper speech recognition system.
///
/// This singleton service provides comprehensive speech recognition functionality:
///
/// Core Features:
/// - Model Management:
///   • Download and storage of Whisper models
///   • Model selection and persistence
///   • Automatic model verification
///   • Hardware-specific optimizations
///
/// Supported Models:
/// - Base: Fast, English-optimized model
/// - Small: High-accuracy English model
/// - Medium: Multilingual model
///
/// Hardware Support:
/// - ARM64 (Apple Silicon) optimization
/// - x86_64 with AVX2 support
/// - Fallback x86_64 compatibility
///
/// Functionality:
/// - Speech transcription
/// - Multiple recording modes
/// - Progress tracking
/// - Error handling
/// - Automatic language detection
///
/// File Management:
/// - Secure model storage
/// - Automatic cleanup
/// - Download progress tracking
/// - Model integrity verification
///
/// Usage:
/// ```swift
/// let manager = WhisperManager.shared
///
/// // Download a model
/// manager.downloadModel(modelSize: "Base")
///
/// // Transcribe audio
/// manager.transcribe(audioURL: url, mode: .transcriptionOnly) { result in
///     switch result {
///     case .success(let transcription):
///         print("Transcription: \(transcription)")
///     case .failure(let error):
///         print("Error: \(error)")
///     }
/// }
/// ```
///
/// Note: This manager handles hardware-specific optimizations automatically,
/// selecting the appropriate Whisper executable based on the system architecture.

import Foundation
import Combine
import AppKit  // Add AppKit import for NSWorkspace and NSApplication

// Move ModelDisplayInfo to WhisperManager since it's model-related metadata
struct ModelDisplayInfo {
    let id: String
    let displayName: String
    let icon: String
    let description: String
    let recommendation: String?  // Optional recommendation text
}

struct CustomModel: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let tag: String
    let downloadURL: String
    
    var fileName: String {
        return URL(string: downloadURL)?.lastPathComponent ?? "\(id).bin"
    }
}

struct WhisperModelInfo: Identifiable {
    let id: String
    let name: String
    let fileName: String
    let size: String
    let fileSize: UInt64
    var isAvailable: Bool
    var isSelected: Bool
    let description: String
    // Add display info
    var displayInfo: ModelDisplayInfo
}

/// Represents a timestamped segment from Whisper transcription
struct WhisperTranscriptionSegment: Codable, Identifiable {
    var id: UUID = UUID()
    let startTime: TimeInterval
    let endTime: TimeInterval
    var text: String
    var translatedText: String? = nil
    var speaker: String? = nil
    var isStarred: Bool? = false
    
    var duration: TimeInterval {
        return endTime - startTime
    }
}

class WhisperManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    static let shared = WhisperManager()

    // Published properties for UI updates
    @Published var isDownloading = false
    @Published var downloadingModelSize: String?
    @Published var downloadProgress: Double = 0.0
    @Published var isReady = false
    @Published var errorMessage: String?
    @Published var availableModels: [WhisperModelInfo] = []
    @Published var customModels: [CustomModel] = []
    @Published var selectedModelSize: String = "small"  // Default model

    // Process management
    private var processQueue = DispatchQueue(label: "com.no-typing.whisper.process", qos: .userInitiated)
    private let processLock = NSLock()
    private var preloadedModel: URL?
    private var preloadedModelSize: String?
    private var isPreloading = false
    private var lastModelUseTime: Date?
    private let modelReloadThreshold: TimeInterval = 300 // 5 minutes

    var whisperModelURL: URL?
    private var modelFileName: String = ""
    private var cancellables = Set<AnyCancellable>()

    // Computed property to get the local URL for the selected model
    private var modelLocalURL: URL {
        getModelDirectory().appendingPathComponent(modelFileName)
    }

    private var downloadSession: URLSession?
    private var downloadTask: URLSessionDownloadTask?

    weak var globalHotkeyManager: GlobalHotkeyManager?

    // Add model display mapping as a static property
    private static let modelDisplayInfo: [String: ModelDisplayInfo] = [
        "base": ModelDisplayInfo(
            id: "base",
            displayName: "Whisper Base",
            icon: "waveform",
            description: "Balanced speed and accuracy. Optimized for stable performance on all Macs.",
            recommendation: "Best for Intel Macs"
        ),
        "small": ModelDisplayInfo(
            id: "small",
            displayName: "Whisper Small",
            icon: "scope",
            description: "Higher accuracy with slightly longer processing time. Ideal when precision matters most.",
            recommendation: "Light and Fast"
        ),
        "large_v3": ModelDisplayInfo(
            id: "large_v3",
            displayName: "Whisper v3",
            icon: "star.circle",
            description: "Highest accuracy model for professional transcription and complex audio.",
            recommendation: "Best for long transcriptions"
        ),
        "large_v3_turbo": ModelDisplayInfo(
            id: "large_v3_turbo",
            displayName: "Whisper v3 Turbo",
            icon: "bolt.circle",
            description: "Optimized large model with faster processing while maintaining high accuracy.",
            recommendation: "Best balance of speed and accuracy"
        ),
        "distil_large_v3.5": ModelDisplayInfo(
            id: "distil_large_v3.5",
            displayName: "Distil Whisper",
            icon: "sparkles",
            description: "Fastest large model. Perfect for English language only.",
            recommendation: "Best for English-only transcription"
        ),
        "parakeet_v2": ModelDisplayInfo(
            id: "parakeet_v2",
            displayName: "Parakeet v2",
            icon: "bird",
            description: "NVIDIA's 0.6B param Fast Conformer TDT model. English-only, up to 300x realtime on Apple Silicon.",
            recommendation: "Good for English transcription (M-series recommended)"
        ),
        "parakeet_v3": ModelDisplayInfo(
            id: "parakeet_v3",
            displayName: "Parakeet v3",
            icon: "bird.fill",
            description: "NVIDIA's multilingual 0.6B param model. Supports 25 European languages with auto-detection.",
            recommendation: "Fastest multilingual (M-series recommended)"
        )
    ]

    override init() {
        super.init()
        loadSelectedModel()
        loadCustomModels()
        loadAvailableModels()
        preloadSelectedModel()
        setupNotifications()
    }

    deinit {
        // No special cleanup needed anymore
    }

    // Get or create the directory for storing Whisper models
    private func getModelDirectory() -> URL {
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let modelDirectory = applicationSupport.appendingPathComponent("Whisper")
        if !FileManager.default.fileExists(atPath: modelDirectory.path) {
            try? FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        }
        return modelDirectory
    }

    // Load custom models from UserDefaults
    private func loadCustomModels() {
        if let data = UserDefaults.standard.data(forKey: "CustomLocalModels"),
           let models = try? JSONDecoder().decode([CustomModel].self, from: data) {
            self.customModels = models
        }
    }

    // Save custom models to UserDefaults
    private func saveCustomModels() {
        if let data = try? JSONEncoder().encode(customModels) {
            UserDefaults.standard.set(data, forKey: "CustomLocalModels")
        }
    }

    // Add a custom model
    func addCustomModel(_ model: CustomModel) {
        customModels.append(model)
        saveCustomModels()
        loadAvailableModels()
        
        // Start downloading the newly added custom model immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.downloadModel(modelSize: model.id)
        }
    }

    // Load the previously selected model from UserDefaults
    private func loadSelectedModel() {
        if let savedModel = UserDefaults.standard.string(forKey: "SelectedWhisperModel") {
            print("📦 [WhisperManager] Loaded model selection: \(savedModel)")
            // Migration for old keys
            if savedModel == "Small" { selectedModelSize = "small" }
            else if savedModel == "largev3" { selectedModelSize = "large_v3" }
            else if savedModel == "largev3turbo" { selectedModelSize = "large_v3_turbo" }
            else { selectedModelSize = savedModel }
        } else {
            // Default based on architecture
            #if arch(arm64)
            selectedModelSize = "small" // Default for Apple Silicon
            #else
            selectedModelSize = "base"  // Default for Intel (CPU)
            #endif
            print("📦 [WhisperManager] No saved selection found, defaulting to: \(selectedModelSize)")
            
            // Save this to UserDefaults immediately to avoid it being nil next time
            UserDefaults.standard.set(selectedModelSize, forKey: "SelectedWhisperModel")
            UserDefaults.standard.synchronize()
        }
    }

    // Load information about available Whisper models
    private func loadAvailableModels() {
        // Include Base, Small, large_v3, large_v3_turbo, and distil models
        let models = [
            ("base", "ggml-base.bin"),
            ("small", "ggml-small.bin"),
            ("large_v3", "ggml-large-v3.bin"),
            ("large_v3_turbo", "ggml-large-v3-turbo.bin"),
            ("distil_large_v3.5", "ggml-distil-large-v3.5.bin"),
            ("parakeet_v2", "sherpa-onnx-nemo-parakeet-tdt-0.6b-v2-int8"),
            ("parakeet_v3", "sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8")
        ]

        var allModels: [(String, String, ModelDisplayInfo?)] = models.map { size, fileName in
            (size, fileName, nil)
        }
        
        for custom in customModels {
            let info = ModelDisplayInfo(
                id: custom.id,
                displayName: custom.name,
                icon: "cpu", // Generic icon for custom models
                description: custom.description,
                recommendation: custom.tag
            )
            allModels.append((custom.id, custom.fileName, info))
        }

        var modelsInfo: [WhisperModelInfo] = []
        var selectedModelAvailable = false

        for (size, fileName, customDisplayInfo) in allModels {
            // For Parakeet models, check via ParakeetManager (directory-based)
            let isAvailable: Bool
            let fileSize: UInt64
            if ParakeetManager.isParakeetModel(size, customFileName: fileName) {
                isAvailable = ParakeetManager.shared.isModelAvailable(modelId: size, customFileName: fileName)
                fileSize = 0 // Directory-based model, skip size calculation
            } else {
                let fileURL = getModelDirectory().appendingPathComponent(fileName)
                isAvailable = FileManager.default.fileExists(atPath: fileURL.path)
                fileSize = isAvailable ? (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? UInt64) ?? 0 : 0
            }
            let sizeString = (isAvailable && fileSize > 0) ? ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file) : ""
            let isSelected = size == selectedModelSize

            if isSelected {
                selectedModelAvailable = true
            }

            // Get display info from static mapping
            let displayInfo = customDisplayInfo ?? Self.modelDisplayInfo[size] ?? ModelDisplayInfo(
                id: size,
                displayName: "Unknown Model",
                icon: "questionmark.circle",
                description: "Unknown model type.",
                recommendation: nil
            )

            let modelInfo = WhisperModelInfo(
                id: size,
                name: displayInfo.displayName, // Use display name instead of default name
                fileName: fileName,
                size: sizeString,
                fileSize: fileSize,
                isAvailable: isAvailable,
                isSelected: isSelected,
                description: displayInfo.description,
                displayInfo: displayInfo
            )

            modelsInfo.append(modelInfo)
        }

        DispatchQueue.main.async {
            self.availableModels = modelsInfo
            self.isReady = selectedModelAvailable
        }
    }

    // Start the setup process for a given model size
    func startSetup(modelSize: String? = nil) {
        // Use provided model size or keep current
        if let size = modelSize {
            if size == "Small" { selectedModelSize = "small" }
            else if size == "largev3" { selectedModelSize = "large_v3" }
            else if size == "largev3turbo" { selectedModelSize = "large_v3_turbo" }
            else { selectedModelSize = size }
            
            // Only save if explicitly changed via parameter
            UserDefaults.standard.set(selectedModelSize, forKey: "SelectedWhisperModel")
            UserDefaults.standard.synchronize()
        }
        
        // Update the UI state
        isReady = availableModels.first(where: { $0.id == selectedModelSize })?.isAvailable ?? false
        
        // Reload models to update UI
        loadAvailableModels()
    }

    func getModelURL(modelSize: String) -> String {
        switch modelSize {
        case "base", "Base":
            return "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin"
        case "small", "Small":
            return "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin"
        case "large_v3", "largev3":
            return "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin"
        case "distil_large_v3.5":
            return "https://huggingface.co/distil-whisper/distil-large-v3.5-ggml/resolve/main/ggml-model.bin"
        case "parakeet_v2":
            return ParakeetManager.modelConfigs["parakeet_v2"]!.downloadURL
        case "parakeet_v3":
            return ParakeetManager.modelConfigs["parakeet_v3"]!.downloadURL
        case "large_v3_turbo", "largev3turbo":
            return "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin"
        default:
            if let customModel = customModels.first(where: { $0.id == modelSize }) {
                return customModel.downloadURL
            } else {
                return "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin" // Default fallback
            }
        }
    }

    // Download the specified Whisper model
    func downloadModel(modelSize: String) {
        // Map model size to file name
        let fileName: String
        let urlString = getModelURL(modelSize: modelSize)
        
        switch modelSize {
        case "base", "Base":
            fileName = "ggml-base.bin"
        case "small", "Small":
            fileName = "ggml-small.bin"
        case "large_v3", "largev3":
            fileName = "ggml-large-v3.bin"
        case "distil_large_v3.5":
            fileName = "ggml-distil-large-v3.5.bin"
        case "parakeet_v2":
            fileName = ParakeetManager.modelConfigs["parakeet_v2"]!.archiveName
        case "parakeet_v3":
            fileName = ParakeetManager.modelConfigs["parakeet_v3"]!.archiveName
        case "large_v3_turbo", "largev3turbo":
            fileName = "ggml-large-v3-turbo.bin"
        default:
            if let customModel = customModels.first(where: { $0.id == modelSize }) {
                fileName = customModel.fileName
            } else {
                fileName = "ggml-large-v3-turbo.bin" // Default fallback
            }
        }
        
        guard let url = URL(string: urlString) else { return }

        cancelDownload()

        isDownloading = true
        downloadingModelSize = modelSize
        downloadProgress = 0.0
        whisperModelURL = url
        modelFileName = fileName
        errorMessage = nil

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300  // 5 min timeout for initial response
        config.timeoutIntervalForResource = 3600 // 1 hour for full download
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        self.downloadSession = session
        let task = session.downloadTask(with: url)
        self.downloadTask = task
        task.resume()
    }

    // Cancel an ongoing download
    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        downloadSession?.invalidateAndCancel()
        downloadSession = nil
        
        let resetState = {
            self.isDownloading = false
            self.downloadingModelSize = nil
            self.downloadProgress = 0.0
        }
        
        if Thread.isMainThread {
            resetState()
        } else {
            DispatchQueue.main.async { resetState() }
        }
    }

    // Select a different Whisper model
    func selectModel(modelSize: String) {
        // For Parakeet models, verify sherpa-onnx binary is available
        if ParakeetManager.isParakeetModel(modelSize) {
            guard ParakeetManager.shared.isSherpaOnnxAvailable() else {
                DispatchQueue.main.async {
                    self.errorMessage = "sherpa-onnx-offline binary not found in app bundle. Please re-install the application."
                }
                return
            }
        }
        
        print("💾 [WhisperManager] Saving model selection: \(modelSize)")
        
        // Use the provided model size
        selectedModelSize = modelSize
        UserDefaults.standard.set(selectedModelSize, forKey: "SelectedWhisperModel")
        UserDefaults.standard.synchronize() // Force write to disk
        
        loadAvailableModels()
        preloadSelectedModel() // Preload the newly selected model
    }

    // Delete a downloaded Whisper model
    func deleteModel(modelSize: String) {
        // Remove from custom models if applicable
        let isCustom = customModels.contains(where: { $0.id == modelSize })
        if let index = customModels.firstIndex(where: { $0.id == modelSize }) {
            customModels.remove(at: index)
            saveCustomModels()
        }

        guard let modelInfo = availableModels.first(where: { $0.id == modelSize }) else { 
            if isCustom { loadAvailableModels() }
            return 
        }

        // For Parakeet models, delete the extracted directory
        let fileURL: URL
        if ParakeetManager.isParakeetModel(modelSize) {
            fileURL = ParakeetManager.shared.modelDirectoryPath(for: modelSize)
            // Also delete the .tar.bz2 archive to free space
            let archiveURL = getModelDirectory().appendingPathComponent(modelInfo.fileName)
            try? FileManager.default.removeItem(at: archiveURL)
        } else {
            fileURL = getModelDirectory().appendingPathComponent(modelInfo.fileName)
        }
        
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            
            if selectedModelSize == modelSize {
                selectedModelSize = ""
                isReady = false
                UserDefaults.standard.setValue(selectedModelSize, forKey: "SelectedWhisperModel")
                
                // Clear preloaded model state
                preloadedModel = nil
                preloadedModelSize = nil
            }
            loadAvailableModels()
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to delete model: \(error.localizedDescription)"
            }
            loadAvailableModels() // still update UI
        }
    }

    /// Generates a minimal valid WAV file (0.1s of silence at 16kHz, mono, 16-bit PCM).
    /// Used for model preloading validation since whisper requires a real audio file.
    private func generateSilentWav(at url: URL) {
        let sampleRate: UInt32 = 16000
        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let numSamples: UInt32 = 1600 // 0.1 seconds at 16kHz
        let dataSize = numSamples * UInt32(numChannels) * UInt32(bitsPerSample / 8)
        
        var data = Data()
        
        // RIFF header
        data.append(contentsOf: "RIFF".utf8)
        var chunkSize = dataSize + 36
        data.append(Data(bytes: &chunkSize, count: 4))
        data.append(contentsOf: "WAVE".utf8)
        
        // fmt sub-chunk
        data.append(contentsOf: "fmt ".utf8)
        var subChunk1Size: UInt32 = 16
        data.append(Data(bytes: &subChunk1Size, count: 4))
        var audioFormat: UInt16 = 1 // PCM
        data.append(Data(bytes: &audioFormat, count: 2))
        var channels = numChannels
        data.append(Data(bytes: &channels, count: 2))
        var rate = sampleRate
        data.append(Data(bytes: &rate, count: 4))
        var byteRate = sampleRate * UInt32(numChannels) * UInt32(bitsPerSample / 8)
        data.append(Data(bytes: &byteRate, count: 4))
        var blockAlign = numChannels * (bitsPerSample / 8)
        data.append(Data(bytes: &blockAlign, count: 2))
        var bps = bitsPerSample
        data.append(Data(bytes: &bps, count: 2))
        
        // data sub-chunk
        data.append(contentsOf: "data".utf8)
        var dataChunkSize = dataSize
        data.append(Data(bytes: &dataChunkSize, count: 4))
        
        // Silent audio samples (all zeros)
        data.append(Data(count: Int(dataSize)))
        
        try? data.write(to: url)
    }
    
    private func preloadSelectedModel() {
        processQueue.async { [weak self] in
            guard let self = self else { return }
            self.processLock.lock()
            defer { self.processLock.unlock() }

            // Skip if already preloading or if no model is selected
            guard !self.isPreloading, 
                  let selectedModel = self.availableModels.first(where: { $0.id == self.selectedModelSize }) else {
                return
            }

            self.isPreloading = true

            let modelPath = self.getModelDirectory().appendingPathComponent(selectedModel.fileName)
            guard FileManager.default.fileExists(atPath: modelPath.path) else {
                print("⚠️ Model file does not exist at path: \(modelPath.path)")
                self.isPreloading = false
                return
            }

            // Create a temporary process to preload the model
            guard let whisperURL = self.getWhisperExecutable() else {
                print("⚠️ Whisper executable not found")
                self.isPreloading = false
                return
            }

            let process = Process()
            process.executableURL = whisperURL
            
            // Generate a tiny silent WAV file for validation
            // (whisper requires a valid audio file, not a text file)
            let tempDir = FileManager.default.temporaryDirectory
            let testWav = tempDir.appendingPathComponent("preload_test_\(UUID().uuidString).wav")
            self.generateSilentWav(at: testWav)

            // Configure process for preloading
            process.arguments = [
                "-m", modelPath.path,
                "-f", testWav.path,
                "--no-timestamps",
                "--language", "auto"
            ]

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe

            do {
                try process.run()
                process.waitUntilExit()
                
                // Clean up test file
                try? FileManager.default.removeItem(at: testWav)
                
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8) ?? ""

                if process.terminationStatus == 0 {
                    print("✅ Model preloaded successfully: \(selectedModel.fileName)")
                    self.preloadedModel = modelPath
                    self.preloadedModelSize = selectedModel.id
                    DispatchQueue.main.async {
                        self.isReady = true
                    }
                } else {
                    print("❌ Failed to preload model (exit code \(process.terminationStatus)): \(output)")
                    self.preloadedModel = nil
                    self.preloadedModelSize = nil
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to preload model. The whisper binary may need to be rebuilt for this architecture."
                    }
                }
            } catch {
                print("❌ Error preloading model: \(error)")
                self.preloadedModel = nil
                self.preloadedModelSize = nil
                DispatchQueue.main.async {
                    self.errorMessage = "Error preloading model: \(error.localizedDescription)"
                }
            }

            self.isPreloading = false
        }
    }

    private func setupNotifications() {
        #if os(macOS)
        // Register for sleep/wake notifications
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSleepNotification(_:)),
            name: NSWorkspace.willSleepNotification,
            object: nil as Any?
        )
        
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWakeNotification(_:)),
            name: NSWorkspace.didWakeNotification,
            object: nil as Any?
        )
        
        // Register for app state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppStateChange(_:)),
            name: NSApplication.willResignActiveNotification,
            object: nil as Any?
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppStateChange(_:)),
            name: NSApplication.didBecomeActiveNotification,
            object: nil as Any?
        )
        #endif
    }

    @objc private func handleSleepNotification(_ notification: Notification) {
        print("💤 System going to sleep - clearing model state")
        processLock.lock()
        defer { processLock.unlock() }
        
        preloadedModel = nil
        preloadedModelSize = nil
        lastModelUseTime = nil
    }

    @objc private func handleWakeNotification(_ notification: Notification) {
        print("⚡️ System waking up - preloading model")
        preloadSelectedModel()
    }

    @objc private func handleAppStateChange(_ notification: Notification) {
        if notification.name == NSApplication.willResignActiveNotification {
            print("📱 App entering background")
            // No immediate action needed, we'll check state when used
        } else if notification.name == NSApplication.didBecomeActiveNotification {
            print("📱 App becoming active - verifying model state")
            verifyModelState()
        }
    }

    private func verifyModelState() {
        processLock.lock()
        defer { processLock.unlock() }
        
        // Check if we need to reload based on time threshold
        if let lastUse = lastModelUseTime,
           Date().timeIntervalSince(lastUse) > modelReloadThreshold {
            print("⚠️ Model state expired - reloading")
            preloadedModel = nil
            preloadedModelSize = nil
            preloadSelectedModel()
        }
    }

    func transcribe(audioURL: URL, mode: RecordingMode, targetLanguage: String? = nil, translateToEnglish: Bool = false, completion: @escaping (Result<String, Error>) -> Void) {
        // Route Parakeet models through ParakeetManager
        if ParakeetManager.isParakeetModel(selectedModelSize) {
            ParakeetManager.shared.transcribe(audioURL: audioURL, modelId: selectedModelSize) { result in
                switch result {
                case .success(let segments):
                    let fullText = segments.map { $0.text }.joined(separator: " ")
                    completion(.success(fullText))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
            return
        }
        
        // Update last use time
        lastModelUseTime = Date()
        
        // Verify model state before proceeding
        verifyModelState()
        
        guard isReady else {
            completion(.failure(NSError(domain: "WhisperManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Model is not ready"])))
            return
        }

        // Ensure we have the correct model loaded
        if preloadedModelSize != selectedModelSize {
            preloadSelectedModel()
        }

        processQueue.async { [weak self] in
            guard let self = self else { return }
            self.processLock.lock()
            defer { self.processLock.unlock() }

            guard let modelURL = self.preloadedModel else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "WhisperManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Model not preloaded"])))
                }
                return
            }

            // Create a temporary directory for this transcription
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("whisper_\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let outputFile = tempDir.appendingPathComponent("transcription")

            let process = Process()
            process.executableURL = self.getWhisperExecutable()

            // Set up pipes for output
            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe

            // Configure arguments based on mode - NOTE: Whisper automatically adds .txt extension to output file
            // Auto-scale thread count: use all available cores, capped at 8
            let threadCount = min(ProcessInfo.processInfo.activeProcessorCount, 8)
            var arguments = [
                "-m", modelURL.path,
                "-otxt",
                "--no-timestamps",
                "-t", "\(threadCount)",  // Auto-scaled for current CPU (arm64 or x86_64)
                "-p", "1",  // Single processor for better latency
                "-bs", "5", // Reduce beam size for faster processing (default is 5)
                "--best-of", "1", // Reduce best-of candidates for speed
                "-of", outputFile.path,
                audioURL.path
            ]
            
            switch mode {
            case .transcriptionOnly:
                if translateToEnglish {
                    arguments += ["-tr"]
                } else {
                    arguments += ["--language", targetLanguage ?? "auto"]
                }
            // case .meetingTranscription has been removed - all transcriptions use the same settings
            }

            process.arguments = arguments
            process.currentDirectoryURL = tempDir

            do {
                try process.run()
                process.waitUntilExit()

                let exitCode = process.terminationStatus
                if exitCode != 0 {
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: outputData, encoding: .utf8) ?? ""
                    throw NSError(domain: "WhisperManager", code: Int(exitCode), 
                                userInfo: [NSLocalizedDescriptionKey: "Process failed: \(output)"])
                }

                // Read the transcription - Whisper adds .txt extension automatically
                let transcriptionFile = outputFile.appendingPathExtension("txt")
                
                // Check if file exists before trying to read it
                if !FileManager.default.fileExists(atPath: transcriptionFile.path) {
                    print("Warning: Transcription file not found at expected path: \(transcriptionFile.path)")
                    print("Directory contents:")
                    if let contents = try? FileManager.default.contentsOfDirectory(atPath: tempDir.path) {
                        print(contents.joined(separator: ", "))
                    }
                    
                    // Try to read from process output instead
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    if let output = String(data: outputData, encoding: .utf8), !output.isEmpty {
                        print("Using process output for transcription instead")
                        throw NSError(domain: "WhisperManager", code: 404, 
                                    userInfo: [NSLocalizedDescriptionKey: "Transcription file not found, but process output available: \(output)"])
                    }
                    
                    throw NSError(domain: "WhisperManager", code: 404, 
                                userInfo: [NSLocalizedDescriptionKey: "Transcription file not found at: \(transcriptionFile.path)"])
                }
                
                // Read the transcription file
                let transcription = try String(contentsOf: transcriptionFile, encoding: .utf8)

                // Clean up
                try? FileManager.default.removeItem(at: tempDir)

                // Filter and process the transcription
                let ignoreSilence = UserDefaults.standard.bool(forKey: "ignoreSilenceSegments")
                let filteredTranscription = transcription
                    .components(separatedBy: .newlines)
                    .map { line -> String in
                        if ignoreSilence {
                            let cleaned = line.replacingOccurrences(of: "\\[.*?\\][.,!?]*|\\(.*?\\)[.,!?]*|♪.*?♪", with: "", options: .regularExpression)
                                .replacingOccurrences(of: "♪", with: "")
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            // If it's just punctuation left, clear it
                            return cleaned.trimmingCharacters(in: CharacterSet(charactersIn: ".,!? ")).isEmpty ? "" : cleaned
                        } else {
                            return line.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                DispatchQueue.main.async {
                    completion(.success(filteredTranscription))
                }
            } catch {
                // Clean up on error
                try? FileManager.default.removeItem(at: tempDir)
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Transcribe audio with timestamps for meeting mode
    func transcribeWithTimestamps(audioURL: URL, recordingStartTime: Date, targetLanguage: String? = nil, translateToEnglish: Bool = false, modelOverride: String? = nil, completion: @escaping (Result<[WhisperTranscriptionSegment], Error>) -> Void) {
        let activeModelId = modelOverride ?? selectedModelSize
        
        // Route Parakeet models through ParakeetManager
        if ParakeetManager.isParakeetModel(activeModelId) {
            ParakeetManager.shared.transcribe(audioURL: audioURL, modelId: activeModelId, completion: completion)
            return
        }
        
        // Update last use time
        lastModelUseTime = Date()
        
        // Verify model state before proceeding
        verifyModelState()
        
        guard let activeModel = availableModels.first(where: { $0.id == activeModelId }), activeModel.isAvailable else {
            completion(.failure(NSError(domain: "WhisperManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Selected model is not ready or available"])))
            return
        }
        
        let resolvedModelURL = getModelDirectory().appendingPathComponent(activeModel.fileName)
        
        guard isReady else {
            completion(.failure(NSError(domain: "WhisperManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Model is not ready"])))
            return
        }

        // Preload in background if this is the globally selected model and it's not preloaded yet
        if activeModelId == selectedModelSize && preloadedModelSize != selectedModelSize {
            preloadSelectedModel()
        }

        processQueue.async { [weak self] in
            guard let self = self else { return }
            self.processLock.lock()
            defer { self.processLock.unlock() }

            // Create a temporary directory for this transcription
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("whisper_\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let outputFile = tempDir.appendingPathComponent("transcription")

            let process = Process()
            process.executableURL = self.getWhisperExecutable()

            // Set up pipes for output
            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe

            // Configure arguments for timestamped output (SRT format for easy parsing)
            var arguments = [
                "-m", resolvedModelURL.path,
                "-osrt",  // Output SRT format for timestamps
                "-of", outputFile.path
            ]
            
            if translateToEnglish {
                arguments += ["-tr"]
            } else {
                arguments += ["--language", targetLanguage ?? "auto"]
            }
            
            arguments += [audioURL.path]

            process.arguments = arguments
            process.currentDirectoryURL = tempDir

            do {
                try process.run()
                process.waitUntilExit()

                let exitCode = process.terminationStatus
                if exitCode != 0 {
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: outputData, encoding: .utf8) ?? ""
                    throw NSError(domain: "WhisperManager", code: Int(exitCode), 
                                userInfo: [NSLocalizedDescriptionKey: "Process failed: \(output)"])
                }

                // Read the SRT file - Whisper adds .srt extension automatically
                let srtFile = outputFile.appendingPathExtension("srt")
                
                // Check if file exists before trying to read it
                if !FileManager.default.fileExists(atPath: srtFile.path) {
                    print("Warning: SRT file not found at expected path: \(srtFile.path)")
                    print("Directory contents:")
                    if let contents = try? FileManager.default.contentsOfDirectory(atPath: tempDir.path) {
                        print(contents.joined(separator: ", "))
                    }
                    
                    throw NSError(domain: "WhisperManager", code: 404, 
                                userInfo: [NSLocalizedDescriptionKey: "SRT file not found at: \(srtFile.path)"])
                }
                
                // Read and parse the SRT file
                let srtContent = try String(contentsOf: srtFile, encoding: .utf8)
                let segments = self.parseSRTContent(srtContent, recordingStartTime: recordingStartTime)

                // Clean up
                try? FileManager.default.removeItem(at: tempDir)

                DispatchQueue.main.async {
                    completion(.success(segments))
                }
            } catch {
                // Clean up on error
                try? FileManager.default.removeItem(at: tempDir)
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Parse SRT content into WhisperTranscriptionSegment objects
    private func parseSRTContent(_ srtContent: String, recordingStartTime: Date) -> [WhisperTranscriptionSegment] {
        var segments: [WhisperTranscriptionSegment] = []
        let lines = srtContent.components(separatedBy: .newlines)
        
        var currentIndex = 0
        while currentIndex < lines.count {
            let line = lines[currentIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines
            if line.isEmpty {
                currentIndex += 1
                continue
            }
            
            // Look for sequence number (should be a number)
            if Int(line) != nil {
                // Next line should be timestamp
                if currentIndex + 1 < lines.count {
                    let timestampLine = lines[currentIndex + 1]
                    
                    // Parse timestamp line (format: "00:00:01,234 --> 00:00:03,456")
                    if let (startTime, endTime) = parseTimestamp(timestampLine) {
                        // Collect text lines until we hit the next sequence number or end
                        var textLines: [String] = []
                        var textIndex = currentIndex + 2
                        
                        while textIndex < lines.count {
                            let textLine = lines[textIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                            if textLine.isEmpty || Int(textLine) != nil {
                                break
                            }
                            textLines.append(textLine)
                            textIndex += 1
                        }
                        
                        // Create segment with cleaned text
                        let fullText = textLines.joined(separator: " ")
                        let cleanedText = cleanTranscriptionText(fullText)
                        
                        if !cleanedText.isEmpty {
                            let segment = WhisperTranscriptionSegment(
                                startTime: startTime,
                                endTime: endTime,
                                text: cleanedText
                            )
                            segments.append(segment)
                        }
                        
                        currentIndex = textIndex
                    } else {
                        currentIndex += 1
                    }
                } else {
                    currentIndex += 1
                }
            } else {
                currentIndex += 1
            }
        }
        
        return segments
    }
    
    /// Parse SRT timestamp line into start and end times (in seconds)
    private func parseTimestamp(_ timestampLine: String) -> (TimeInterval, TimeInterval)? {
        // Format: "00:00:01,234 --> 00:00:03,456"
        let components = timestampLine.components(separatedBy: " --> ")
        guard components.count == 2 else { return nil }
        
        guard let startTime = parseSRTTime(components[0]),
              let endTime = parseSRTTime(components[1]) else {
            return nil
        }
        
        return (startTime, endTime)
    }
    
    /// Parse SRT time format into seconds
    private func parseSRTTime(_ timeString: String) -> TimeInterval? {
        // Format: "00:00:01,234"
        let cleaned = timeString.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = cleaned.components(separatedBy: ",")
        guard parts.count == 2 else { return nil }
        
        let timePart = parts[0]
        guard let milliseconds = Int(parts[1]) else { return nil }
        
        let timeComponents = timePart.components(separatedBy: ":")
        guard timeComponents.count == 3,
              let hours = Int(timeComponents[0]),
              let minutes = Int(timeComponents[1]),
              let seconds = Int(timeComponents[2]) else {
            return nil
        }
        
        let totalSeconds = TimeInterval(hours * 3600 + minutes * 60 + seconds)
        let totalMilliseconds = totalSeconds + TimeInterval(milliseconds) / 1000.0
        
        return totalMilliseconds
    }
    
    /// Clean transcription text by removing unwanted patterns
    private func cleanTranscriptionText(_ text: String) -> String {
        let ignoreSilence = UserDefaults.standard.bool(forKey: "ignoreSilenceSegments")
        guard ignoreSilence else { return text.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        let cleaned = text
            .replacingOccurrences(of: "\\[.*?\\][.,!?]*|\\(.*?\\)[.,!?]*|♪.*?♪", with: "", options: .regularExpression)
            .replacingOccurrences(of: "♪", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            
        // If it's just punctuation left, return empty
        return cleaned.trimmingCharacters(in: CharacterSet(charactersIn: ".,!? ")).isEmpty ? "" : cleaned
    }

    // MARK: - URLSessionDownloadDelegate Methods

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            let fileManager = FileManager.default

            // Use the explicitly tracked modelFileName if available, fallback to URL
            let destinationFileName = self.modelFileName ?? getFileName(for: downloadTask.originalRequest?.url)
            let destinationURL = getModelDirectory().appendingPathComponent(destinationFileName)
            
            // Validate downloaded file size (reject tiny files - likely error pages)
            let downloadedAttributes = try fileManager.attributesOfItem(atPath: location.path)
            let downloadedSize = downloadedAttributes[.size] as? UInt64 ?? 0
            let minimumSize: UInt64 = 1_000_000 // 1MB minimum - real models are hundreds of MB
            
            if downloadedSize < minimumSize {
                // Likely an HTML error page, not a real model
                try? fileManager.removeItem(at: location)
                DispatchQueue.main.async {
                    self.errorMessage = "Download failed: received invalid file (\(ByteCountFormatter.string(fromByteCount: Int64(downloadedSize), countStyle: .file))). The model may not be available at this URL."
                    self.isDownloading = false
                    self.downloadingModelSize = nil
                    self.downloadProgress = 0.0
                }
                return
            }
            
            // Check if this is a Parakeet model (tar.bz2 archive that needs extraction)
            let isParakeet = destinationFileName.hasSuffix(".tar.bz2")
            
            if isParakeet {
                // Move archive to model directory first
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.moveItem(at: location, to: destinationURL)
                
                // Determine which Parakeet model this is
                let modelId = self.downloadingModelSize ?? ""
                
                // Extract on background thread
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        try ParakeetManager.shared.extractModelArchive(archivePath: destinationURL, modelId: modelId)
                        
                        DispatchQueue.main.async {
                            self.isDownloading = false
                            self.downloadingModelSize = nil
                            self.downloadProgress = 1.0
                            self.selectModel(modelSize: modelId)
                            self.loadAvailableModels()
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.errorMessage = "Model extraction failed: \(error.localizedDescription)"
                            self.isDownloading = false
                            self.downloadingModelSize = nil
                            self.downloadProgress = 0.0
                        }
                    }
                }
            } else {
                // Standard Whisper model - single file
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.moveItem(at: location, to: destinationURL)

                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.downloadingModelSize = nil
                    self.downloadProgress = 1.0
                    self.isReady = true
                    
                    // Automatically select the newly downloaded model
                    if let modelSize = self.availableModels.first(where: { $0.fileName == destinationFileName })?.id {
                        self.selectModel(modelSize: modelSize)
                    }
                    
                    self.loadAvailableModels()
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
                self.isDownloading = false
                self.downloadingModelSize = nil
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error as NSError? {
            // Ignore cancel errors as they are manually triggered
            if error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
                return
            }
            
            var friendlyMessage = error.localizedDescription
            
            // Provide human-readable errors for common network issues
            if error.domain == NSURLErrorDomain {
                if error.code == NSURLErrorCannotFindHost {
                    friendlyMessage = "Network error: Please check your internet connection."
                } else if error.code == NSURLErrorNotConnectedToInternet {
                    friendlyMessage = "Network error: You are not connected to the internet."
                } else if error.code == NSURLErrorTimedOut {
                    friendlyMessage = "Network error: The download timed out. Please try again later."
                }
            }
            
            DispatchQueue.main.async {
                self.errorMessage = friendlyMessage
                self.isDownloading = false
                self.downloadingModelSize = nil
            }
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        
        var expectedBytes = totalBytesExpectedToWrite
        
        // Fallback for GitHub releases where expected bytes might be -1
        if expectedBytes <= 0 {
            let modelId = self.downloadingModelSize ?? ""
            if modelId == "parakeet_v2" {
                expectedBytes = 482_468_385 // Exact size from curl
            } else if modelId == "parakeet_v3" {
                expectedBytes = 485_050_000 // Approximate size
            } else {
                expectedBytes = downloadTask.response?.expectedContentLength ?? -1
            }
        }
        
        // Calculate progress, ensuring we don't divide by zero or negative
        let progress: Double
        if expectedBytes > 0 {
            progress = Double(totalBytesWritten) / Double(expectedBytes)
        } else {
            progress = min(0.99, self.downloadProgress + 0.001)
        }
        
        DispatchQueue.main.async {
            self.downloadProgress = max(0.0, min(1.0, progress))
        }
    }

    // Helper functions to get URLs and file names...

    private func getFileName(for url: URL?) -> String {
        return url?.lastPathComponent ?? "downloaded_file"
    }

    private func detectCPUCapabilities() -> (architecture: String, features: Set<String>) {
        #if arch(arm64)
        return ("arm64", ["neon", "arm64"])
        #else
        return ("x86_64", ["x86_64"])
        #endif
    }

    private func getWhisperExecutable() -> URL? {
        // Universal binary supporting both Apple Silicon (arm64) and Intel (x86_64)
        return Bundle.main.url(forResource: "whisper", withExtension: nil)
    }

    func waitUntilReady() async {
        // Wait for up to 5 seconds for the model to be ready
        for _ in 0..<50 {
            if isReady {
                return
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }
    }
}