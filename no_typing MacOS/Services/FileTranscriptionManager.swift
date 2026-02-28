import Foundation
import Combine
import AVFoundation

class FileTranscriptionManager: ObservableObject {
    static let shared = FileTranscriptionManager()
    
    @Published var isTranscribing: Bool = false
    @Published var transcribedText: String = ""
    @Published var wordCount: Int = 0
    @Published var errorMessage: String?
    @Published var currentFileName: String?
    
    @Published var transcriptionQueue: [URL] = []
    @Published var totalInBatch: Int = 0
    @Published var translateToEnglish: Bool = false
    
    @Published var useCloudEngine: Bool = false
    @Published var cloudProvider: CloudTranscriptionProvider = .deepgram
    
    private init() {}
    
    func queueFiles(_ urls: [URL]) {
        transcriptionQueue.append(contentsOf: urls)
        if totalInBatch == 0 {
            totalInBatch = urls.count
        } else {
            totalInBatch += urls.count
        }
        
        processNextIfAvailable()
    }
    
    private func processNextIfAvailable() {
        guard !isTranscribing else { return }
        
        guard !transcriptionQueue.isEmpty else {
            // Batch is completely finished
            totalInBatch = 0
            return
        }
        
        let url = transcriptionQueue.removeFirst()
        transcribeFile(url: url)
    }

    func transcribeFile(url: URL) {
        guard !isTranscribing else { return }
        
        if useCloudEngine {
            transcribeFileCloud(url: url)
            return
        }
        
        isTranscribing = true
        errorMessage = nil
        currentFileName = url.lastPathComponent
        
        NotificationManager.shared.requestAuthorization()
        
        let duration = getAudioDuration(url: url)
        
        convertTo16kHzWav(sourceURL: url) { [weak self] conversionResult in
            switch conversionResult {
            case .success(let wavURL):
                WhisperManager.shared.transcribeWithTimestamps(
                    audioURL: wavURL,
                    recordingStartTime: Date(),
                    targetLanguage: nil,
                    translateToEnglish: self?.translateToEnglish ?? false
                ) { result in
                    DispatchQueue.main.async {
                        self?.isTranscribing = false
                        self?.currentFileName = nil
                        
                        // Clean up the temporary wav file
                        try? FileManager.default.removeItem(at: wavURL)
                        
                        switch result {
                        case .success(let segments):
                            let rawText = segments.map { $0.text }.joined(separator: " ")
                            let cleanedText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
                            // let formattedText = self?.formatTranscriptionAsParagraphs(cleanedText) ?? cleanedText
                            let formattedText = cleanedText
                            self?.transcribedText = formattedText
                            
                            // Calculate word count
                            let words = formattedText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
                            self?.wordCount = words.count
                            
                            var bookmarkData: Data? = nil
                            do {
                                let isSecurityScoped = url.startAccessingSecurityScopedResource()
                                bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                                if isSecurityScoped {
                                    url.stopAccessingSecurityScopedResource()
                                }
                            } catch {
                                print("Warning: Failed to create security-scoped bookmark for media: \(error.localizedDescription)")
                            }
                            
                            if !formattedText.isEmpty {
                                TranscriptionHistoryManager.shared.addTranscription(
                                    formattedText,
                                    duration: duration,
                                    segments: segments,
                                    sourceMediaData: bookmarkData
                                )
                                
                                // Forward to file transcription webhook if configured
                                if let idString = UserDefaults.standard.string(forKey: "fileTranscriptionWebhookEndpointId"),
                                   let endpointId = UUID(uuidString: idString) {
                                    WebhookManager.shared.sendTranscript(text: formattedText, duration: duration, endpointId: endpointId)
                                }
                            }
                            
                            NotificationManager.shared.sendNotification(
                                title: "Transcription Completed",
                                body: "Your text is ready!"
                            )
                            
                        case .failure(let error):
                            self?.errorMessage = error.localizedDescription
                            NotificationManager.shared.sendNotification(
                                title: "Transcription Failed",
                                body: "Error: \(error.localizedDescription)"
                            )
                        }
                        
                        // Move to next file in queue
                        self?.processNextIfAvailable()
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self?.isTranscribing = false
                    self?.currentFileName = nil
                    self?.errorMessage = "Failed to convert audio format: \(error.localizedDescription)"
                    NotificationManager.shared.sendNotification(
                        title: "Format Conversion Failed",
                        body: "Could not read audio file: \(error.localizedDescription)"
                    )
                    
                    self?.processNextIfAvailable()
                }
            }
        }
    }
    
    // MARK: - Cloud Transcription
    private func transcribeFileCloud(url: URL) {
        isTranscribing = true
        errorMessage = nil
        currentFileName = url.lastPathComponent
        
        NotificationManager.shared.requestAuthorization()
        let duration = getAudioDuration(url: url)
        let provider = cloudProvider
        
        Task {
            do {
                let segments = try await CloudTranscriptionManager.shared.transcribe(audioURL: url, provider: provider)
                
                await MainActor.run {
                    let rawText = segments.map { $0.text }.joined(separator: " ")
                    let cleanedText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
                    let formattedText = cleanedText
                    self.transcribedText = formattedText
                    
                    let words = formattedText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
                    self.wordCount = words.count
                    
                    var bookmarkData: Data? = nil
                    do {
                        let isSecurityScoped = url.startAccessingSecurityScopedResource()
                        bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                        if isSecurityScoped {
                            url.stopAccessingSecurityScopedResource()
                        }
                    } catch {
                        print("Warning: Failed to create security-scoped bookmark for media: \(error.localizedDescription)")
                    }
                    
                    if !formattedText.isEmpty {
                        TranscriptionHistoryManager.shared.addTranscription(
                            formattedText,
                            duration: duration,
                            segments: segments,
                            sourceMediaData: bookmarkData
                        )
                        
                        // Forward to file transcription webhook if configured
                        if let idString = UserDefaults.standard.string(forKey: "fileTranscriptionWebhookEndpointId"),
                           let endpointId = UUID(uuidString: idString) {
                            WebhookManager.shared.sendTranscript(text: formattedText, duration: duration, endpointId: endpointId)
                        }
                    }
                    
                    NotificationManager.shared.sendNotification(
                        title: "Cloud Transcription Completed",
                        body: "Transcribed via \(provider.rawValue)"
                    )
                    
                    self.isTranscribing = false
                    self.currentFileName = nil
                    self.processNextIfAvailable()
                }
            } catch {
                await MainActor.run {
                    self.isTranscribing = false
                    self.currentFileName = nil
                    self.errorMessage = error.localizedDescription
                    NotificationManager.shared.sendNotification(
                        title: "Cloud Transcription Failed",
                        body: error.localizedDescription
                    )
                    self.processNextIfAvailable()
                }
            }
        }
    }
    
    func clearResult() {
        transcribedText = ""
        wordCount = 0
        errorMessage = nil
    }
    
    private func getAudioDuration(url: URL) -> TimeInterval {
        let asset = AVURLAsset(url: url)
        return CMTimeGetSeconds(asset.duration)
    }
    
    // MARK: - Smart Formatting
    
    /// intelligently injects paragraph breaks into raw transcription blocks
    private func formatTranscriptionAsParagraphs(_ text: String, sentencesPerParagraph: Int = 5) -> String {
        guard !text.isEmpty else { return text }
        
        var paragraphs: [String] = []
        var currentParagraphTokens: [String] = []
        var sentenceCount = 0
        
        let tagger = NSLinguisticTagger(tagSchemes: [.tokenType], options: 0)
        tagger.string = text
        let range = NSRange(location: 0, length: text.utf16.count)
        let options: NSLinguisticTagger.Options = [.omitWhitespace, .joinNames]
        
        tagger.enumerateTags(in: range, unit: .sentence, scheme: .tokenType, options: options) { tag, tokenRange, stop in
            if let sentenceRange = Range(tokenRange, in: text) {
                let sentence = String(text[sentenceRange]).trimmingCharacters(in: .whitespaces)
                currentParagraphTokens.append(sentence)
                sentenceCount += 1
                
                if sentenceCount >= sentencesPerParagraph {
                    paragraphs.append(currentParagraphTokens.joined(separator: " "))
                    currentParagraphTokens.removeAll()
                    sentenceCount = 0
                }
            }
        }
        
        if !currentParagraphTokens.isEmpty {
            paragraphs.append(currentParagraphTokens.joined(separator: " "))
        }
        
        return paragraphs.joined(separator: "\n\n")
    }
    
    // MARK: - Format Conversion
    
    private func convertTo16kHzWav(sourceURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        let tempDir = FileManager.default.temporaryDirectory
        let outputURL = tempDir.appendingPathComponent("transcode_\(UUID().uuidString).wav")
        
        do {
            let asset = AVURLAsset(url: sourceURL)
            guard let audioTrack = asset.tracks(withMediaType: .audio).first else {
                completion(.failure(NSError(domain: "FileTranscriptionManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No audio track found in file."])))
                return
            }
            
            let assetReader = try AVAssetReader(asset: asset)
            
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 16000,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsNonInterleaved: false,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false
            ]
            
            let trackOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: settings)
            guard assetReader.canAdd(trackOutput) else {
                completion(.failure(NSError(domain: "FileTranscriptionManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot add track output"])))
                return
            }
            assetReader.add(trackOutput)
            
            let assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .wav)
            let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: settings)
            writerInput.expectsMediaDataInRealTime = false
            
            guard assetWriter.canAdd(writerInput) else {
                completion(.failure(NSError(domain: "FileTranscriptionManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot add writer input"])))
                return
            }
            assetWriter.add(writerInput)
            
            guard assetReader.startReading() else {
                let errorDesc = assetReader.error?.localizedDescription ?? "Unknown failure"
                completion(.failure(NSError(domain: "FileTranscriptionManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to start reading: \(errorDesc)"])))
                return
            }
            
            guard assetWriter.startWriting() else {
                let errorDesc = assetWriter.error?.localizedDescription ?? "Unknown failure"
                completion(.failure(NSError(domain: "FileTranscriptionManager", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to start writing: \(errorDesc)"])))
                return
            }
            
            assetWriter.startSession(atSourceTime: .zero)
            
            let conversionQueue = DispatchQueue(label: "com.no_typing.audio_conversion")
            
            writerInput.requestMediaDataWhenReady(on: conversionQueue) {
                // Explicitly capture assetReader to prevent it from being deallocated by ARC
                // when the outer function scope exits.
                _ = assetReader
                
                while writerInput.isReadyForMoreMediaData {
                    if let sampleBuffer = trackOutput.copyNextSampleBuffer() {
                        writerInput.append(sampleBuffer)
                    } else {
                        writerInput.markAsFinished()
                        
                        assetWriter.finishWriting {
                            if assetWriter.status == .completed {
                                completion(.success(outputURL))
                            } else {
                                completion(.failure(assetWriter.error ?? NSError(domain: "FileTranscriptionManager", code: 6, userInfo: [NSLocalizedDescriptionKey: "Unknown writer error."])))
                            }
                        }
                        return
                    }
                }
            }
            
        } catch {
            completion(.failure(error))
        }
    }
}
