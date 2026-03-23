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
    @Published var currentPhase: String = ""
    
    @Published var elapsedTime: TimeInterval = 0
    @Published var lastTranscriptionDuration: TimeInterval = 0
    private var timer: Timer?
    private var isCancelled: Bool = false
    
    @Published var transcriptionQueue: [URL] = []
    @Published var totalInBatch: Int = 0
    @Published var translateToEnglish: Bool = false
    
    @Published var selectedLocalModel: String = UserDefaults.standard.string(forKey: "fileTranscriptionLocalModel") ?? "small" {
        didSet { UserDefaults.standard.set(selectedLocalModel, forKey: "fileTranscriptionLocalModel") }
    }
    
    @Published var useCloudEngine: Bool = UserDefaults.standard.bool(forKey: "cloudTranscriptionEnabled") {
        didSet { UserDefaults.standard.set(useCloudEngine, forKey: "cloudTranscriptionEnabled") }
    }
    
    @Published var cloudProvider: CloudTranscriptionProvider = CloudTranscriptionProvider(rawValue: UserDefaults.standard.string(forKey: "cloudTranscriptionProvider") ?? "Deepgram") ?? .deepgram {
        didSet { UserDefaults.standard.set(cloudProvider.rawValue, forKey: "cloudTranscriptionProvider") }
    }
    
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
    
    // MARK: - Podcast Multi-Track (labeled per host)
    
    /// Transcribes each track individually and formats the result as:
    ///   [Speaker]\n<text>\n\n[Speaker]\n<text>\n\n...
    func transcribePodcastTracks(_ trackURLs: [URL], speakerNames: [String] = []) {
        guard !isTranscribing else { return }
        
        isCancelled = false
        isTranscribing = true
        errorMessage = nil
        transcribedText = ""
        wordCount = 0
        currentPhase = "Transcribing"
        currentFileName = trackURLs.first?.lastPathComponent
        totalInBatch = trackURLs.count
        startTimer()
        
        NotificationManager.shared.requestAuthorization()
        
        // Kick off recursive per-track processing
        transcribeNextPodcastTrack(trackURLs: trackURLs, speakerNames: speakerNames, index: 0, results: [])
    }
    
    private func transcribeNextPodcastTrack(trackURLs: [URL], speakerNames: [String], index: Int, results: [String]) {
        guard !isCancelled else { return }
        
        if index >= trackURLs.count {
            // Build (label, text) pairs
            let pairs: [(String, String)] = results.enumerated().map { i, text in
                let label = (i < speakerNames.count && !speakerNames[i].trimmingCharacters(in: .whitespaces).isEmpty)
                    ? speakerNames[i]
                    : "Host \(i + 1)"
                return (label, text)
            }
            
            // Merge consecutive segments that share the same speaker
            var merged: [(String, String)] = []
            for (label, text) in pairs {
                if let last = merged.last, last.0 == label {
                    merged[merged.count - 1] = (label, last.1 + "\n\n" + text)
                } else {
                    merged.append((label, text))
                }
            }
            
            let formatted = merged.map { label, text in
                "[\(label)]\n\(text)"
            }.joined(separator: "\n\n")
            
            DispatchQueue.main.async {
                self.transcribedText = formatted
                let words = formatted.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
                self.wordCount = words.count
                self.isTranscribing = false
                self.stopTimerSavingDuration()
                self.currentFileName = nil
                self.currentPhase = ""
                self.totalInBatch = 0
                
                if !formatted.isEmpty {
                    TranscriptionHistoryManager.shared.addTranscription(
                        formatted,
                        duration: 0,
                        segments: [],
                        sourceMediaData: nil
                    )
                }
                NotificationManager.shared.sendNotification(
                    title: "Podcast Transcription Completed",
                    body: "Transcribed \(trackURLs.count) tracks."
                )
            }
            return
        }
        
        let trackURL = trackURLs[index]
        let speakerLabel = (index < speakerNames.count && !speakerNames[index].trimmingCharacters(in: .whitespaces).isEmpty)
            ? speakerNames[index]
            : "Host \(index + 1)"
        DispatchQueue.main.async {
            self.currentFileName = trackURL.lastPathComponent
            self.currentPhase = "Transcribing \(speakerLabel) (\(index + 1) of \(trackURLs.count))"
        }
        
        convertTo16kHzWav(sourceURL: trackURL) { [weak self] conversionResult in
            guard let self = self, !self.isCancelled else { return }
            switch conversionResult {
            case .success(let wavURL):
                WhisperManager.shared.transcribeWithTimestamps(
                    audioURL: wavURL,
                    recordingStartTime: Date(),
                    targetLanguage: nil,
                    translateToEnglish: self.translateToEnglish,
                    modelOverride: self.selectedLocalModel
                ) { result in
                    try? FileManager.default.removeItem(at: wavURL)
                    guard !self.isCancelled else { return }
                    
                    var hostText = ""
                    if case .success(let segments) = result {
                        hostText = segments.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    // Continue to next track (even if this one failed/empty)
                    self.transcribeNextPodcastTrack(
                        trackURLs: trackURLs,
                        speakerNames: speakerNames,
                        index: index + 1,
                        results: results + [hostText]
                    )
                }
            case .failure:
                // Skip failed track, continue
                self.transcribeNextPodcastTrack(
                    trackURLs: trackURLs,
                    speakerNames: speakerNames,
                    index: index + 1,
                    results: results + [""]
                )
            }
        }
    }

    func transcribeFile(url: URL) {
        guard !isTranscribing else { return }
        
        if useCloudEngine {
            transcribeFileCloud(url: url)
            return
        }
        
        isCancelled = false
        isTranscribing = true
        errorMessage = nil
        currentPhase = "Transcribing"
        currentFileName = url.lastPathComponent
        startTimer()
        
        NotificationManager.shared.requestAuthorization()
        
        let duration = getAudioDuration(url: url)
        
        convertTo16kHzWav(sourceURL: url) { [weak self] conversionResult in
            if self?.isCancelled == true { return }
            switch conversionResult {
            case .success(let wavURL):
                WhisperManager.shared.transcribeWithTimestamps(
                    audioURL: wavURL,
                    recordingStartTime: Date(),
                    targetLanguage: nil,
                    translateToEnglish: self?.translateToEnglish ?? false,
                    modelOverride: self?.selectedLocalModel
                ) { result in
                    DispatchQueue.main.async {
                        if self?.isCancelled == true { return }
                        self?.isTranscribing = false
                        self?.stopTimerSavingDuration()
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
                    if self?.isCancelled == true { return }
                    self?.isTranscribing = false
                    self?.stopTimerSavingDuration()
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
        isCancelled = false
        isTranscribing = true
        errorMessage = nil
        currentPhase = "Transcribing"
        currentFileName = url.lastPathComponent
        startTimer()
        
        NotificationManager.shared.requestAuthorization()
        let duration = getAudioDuration(url: url)
        let provider = cloudProvider
        
        Task {
            do {
                let segments = try await CloudTranscriptionManager.shared.transcribe(audioURL: url, provider: provider)
                
                await MainActor.run {
                    if self.isCancelled { return }
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
                    self.stopTimerSavingDuration()
                    self.currentFileName = nil
                    self.processNextIfAvailable()
                }
            } catch {
                await MainActor.run {
                    if self.isCancelled { return }
                    self.isTranscribing = false
                    self.stopTimerSavingDuration()
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
        currentPhase = ""
    }
    
    func cancelTranscription() {
        isCancelled = true
        isTranscribing = false
        stopTimer()
        transcriptionQueue.removeAll()
        totalInBatch = 0
        errorMessage = "Transcription cancelled."
        currentFileName = nil
        currentPhase = ""
    }
    
    func startTimer() {
        stopTimer()
        elapsedTime = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.elapsedTime += 1
        }
    }
    
    func stopTimerSavingDuration() {
        lastTranscriptionDuration = elapsedTime
        stopTimer()
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
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
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let file = try AVAudioFile(forReading: sourceURL)
                let format = file.processingFormat
                
                // We want standard 16kHz, mono, 16-bit integer PCM Standard Format!
                guard let outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                                       sampleRate: 16000,
                                                       channels: 1,
                                                       interleaved: false) else {
                    completion(.failure(NSError(domain: "FileTranscriptionManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create output audio format"])))
                    return
                }
                
                // Audio converter for resampling
                guard let converter = AVAudioConverter(from: format, to: outputFormat) else {
                    completion(.failure(NSError(domain: "FileTranscriptionManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio converter"])))
                    return
                }
                
                let frameCapacity = AVAudioFrameCount(file.length)
                guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
                    completion(.failure(NSError(domain: "FileTranscriptionManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to allocate input buffer"])))
                    return
                }
                
                try file.read(into: inputBuffer)
                
                // Calculate output buffer size needed
                let outputFrameCapacity = AVAudioFrameCount(Double(frameCapacity) * (outputFormat.sampleRate / format.sampleRate))
                guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputFrameCapacity) else {
                    completion(.failure(NSError(domain: "FileTranscriptionManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to allocate output buffer"])))
                    return
                }
                
                var error: NSError?
                let status = converter.convert(to: outputBuffer, error: &error) { packetCount, outStatus in
                    outStatus.pointee = .haveData
                    return inputBuffer
                }
                
                if let err = error {
                    completion(.failure(err))
                    return
                }
                
                if status == .error {
                    completion(.failure(NSError(domain: "FileTranscriptionManager", code: 5, userInfo: [NSLocalizedDescriptionKey: "Conversion failed"])))
                    return
                }
                
                
                // Construct standard WAV header manually to bypass Extensible generation in AVAudioFile
                let frameLength = outputBuffer.frameLength
                guard let channelData = outputBuffer.int16ChannelData else {
                    completion(.failure(NSError(domain: "FileTranscriptionManager", code: 6, userInfo: [NSLocalizedDescriptionKey: "Failed to get PCM data from buffer"])))
                    return
                }
                
                let dataSize = UInt32(frameLength) * 2 // 1 channel, 16-bit (2 bytes) per sample
                var pcmData = Data()
                
                // 1. RIFF
                pcmData.append(contentsOf: "RIFF".utf8)
                var fileSize = dataSize + 36
                pcmData.append(Data(bytes: &fileSize, count: 4))
                
                // 2. WAVE
                pcmData.append(contentsOf: "WAVE".utf8)
                
                // 3. fmt chunk
                pcmData.append(contentsOf: "fmt ".utf8)
                var fmtSize: UInt32 = 16 // Standard PCM fmt chunk is exactly 16 bytes
                pcmData.append(Data(bytes: &fmtSize, count: 4))
                var formatTag: UInt16 = 1 // 1 = Standard PCM
                pcmData.append(Data(bytes: &formatTag, count: 2))
                var channels: UInt16 = 1
                pcmData.append(Data(bytes: &channels, count: 2))
                var sampleRate: UInt32 = 16000
                pcmData.append(Data(bytes: &sampleRate, count: 4))
                var byteRate: UInt32 = 16000 * 2 // sampleRate * channels * bytesPerSample
                pcmData.append(Data(bytes: &byteRate, count: 4))
                var blockAlign: UInt16 = 2
                pcmData.append(Data(bytes: &blockAlign, count: 2))
                var bitsPerSample: UInt16 = 16
                pcmData.append(Data(bytes: &bitsPerSample, count: 2))
                
                // 4. data chunk
                pcmData.append(contentsOf: "data".utf8)
                var customDataSize = dataSize
                pcmData.append(Data(bytes: &customDataSize, count: 4))
                
                // Append the raw PCM bytes directly
                let byteCount = Int(frameLength) * 2
                let rawPointer = UnsafeRawBufferPointer(start: channelData[0], count: byteCount)
                pcmData.append(contentsOf: rawPointer)
                
                try pcmData.write(to: outputURL)
                completion(.success(outputURL))
                
            } catch {
                completion(.failure(error))
            }
        }
    }
}
