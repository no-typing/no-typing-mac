import Foundation
import AVFoundation
import Combine

class AudioProcessingQueueService: ObservableObject {
    // Processing queue for audio segments
    private var processingQueue: [(URL, Date)] = []
    private var isCurrentlyProcessing = false
    
    // Throttling for audio processing
    private var lastProcessingTime: Date?
    private let processingThrottle: TimeInterval = 0.1
    
    // Dependencies
    private let audioTranscriptionService: AudioTranscriptionService
    private let whisperManager: WhisperManager
    
    // State
    @Published private(set) var queueLength: Int = 0
    
    init(audioTranscriptionService: AudioTranscriptionService, whisperManager: WhisperManager = WhisperManager.shared) {
        self.audioTranscriptionService = audioTranscriptionService
        self.whisperManager = whisperManager
        
        // Set up notification observer for audio segments ready for processing
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSegmentReady),
            name: NSNotification.Name("AudioSegmentReadyForProcessing"),
            object: nil
        )
    }
    
    @objc private func handleAudioSegmentReady(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let audioURL = userInfo["audioURL"] as? URL,
              let timestamp = userInfo["timestamp"] as? Date else {
            print("Error: Invalid notification data for audio segment processing")
            return
        }
        
        addToProcessingQueue(audioURL: audioURL, timestamp: timestamp)
    }
    
    func addToProcessingQueue(audioURL: URL, timestamp: Date) {
        DispatchQueue.main.async {
            self.processingQueue.append((audioURL, timestamp))
            self.queueLength = self.processingQueue.count
            self.processNextInQueue()
        }
    }
    
    func processNextInQueue() {
        // If already processing or queue is empty, return
        guard !isCurrentlyProcessing, !processingQueue.isEmpty else { return }
        
        // Mark as processing
        isCurrentlyProcessing = true
        
        // Get next item to process
        let (audioURL, timestamp) = processingQueue.removeFirst()
        queueLength = processingQueue.count
        
        print("🎯 Processing queued audio segment...")
        
        // Use high-priority queue for transcription
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let useLocalWhisperModel = self.audioTranscriptionService.useLocalWhisperModel
            
            if useLocalWhisperModel && self.whisperManager.isReady {
                self.processWithWhisper(audioURL: audioURL, timestamp: timestamp)
            } else {
                self.processWithCloud(audioURL: audioURL, timestamp: timestamp)
            }
        }
    }
    
    private func processWithWhisper(audioURL: URL, timestamp: Date) {
        let selectedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "english"
        
        let asset = AVURLAsset(url: audioURL)
        let audioDuration = CMTimeGetSeconds(asset.duration)
        
        whisperManager.transcribe(
            audioURL: audioURL,
            mode: .transcriptionOnly,
            targetLanguage: selectedLanguage
        ) { [weak self] result in
            guard let self = self else { return }
            
            // Clean up immediately after getting result
            try? FileManager.default.removeItem(at: audioURL)
            
            DispatchQueue.main.async {
                switch result {
                case .success(let transcription):
                    self.audioTranscriptionService.handleTranscriptionResult(transcription, duration: audioDuration)
                case .failure(let error):
                    print("Transcription error: \(error)")
                }
                
                // Mark as done and process next
                self.isCurrentlyProcessing = false
                self.processNextInQueue()
            }
        }
    }

    
    private func processWithCloud(audioURL: URL, timestamp: Date) {
        let providerString = UserDefaults.standard.string(forKey: "cloudTranscriptionProvider") ?? ""
        let provider = CloudTranscriptionProvider(rawValue: providerString) ?? .deepgram
        
        let selectedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "auto"
        
        print("☁️ Processing with cloud provider: \(provider.rawValue)")
        
        Task {
            do {
                let segments = try await CloudTranscriptionManager.shared.transcribe(
                    audioURL: audioURL, 
                    provider: provider, 
                    language: selectedLanguage
                )
                
                // Clean up immediately after getting result
                try? FileManager.default.removeItem(at: audioURL)
                
                await MainActor.run {
                    // Combine segments into a single transcription string
                    let transcription = segments.map { $0.text }.joined(separator: " ")
                    
                    let asset = AVURLAsset(url: audioURL)
                    let audioDuration = CMTimeGetSeconds(asset.duration)
                    
                    self.audioTranscriptionService.handleTranscriptionResult(transcription, duration: audioDuration)
                    
                    // Mark as done and process next
                    self.isCurrentlyProcessing = false
                    self.processNextInQueue()
                }
            } catch {
                print("Cloud Transcription error: \(error)")
                try? FileManager.default.removeItem(at: audioURL)
                
                await MainActor.run {
                    // Mark as done and process next even on failure
                    self.isCurrentlyProcessing = false
                    self.processNextInQueue()
                }
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
