import Foundation
import Combine
import AVFoundation

class FileTranscriptionManager: ObservableObject {
    static let shared = FileTranscriptionManager()
    
    @Published var isTranscribing: Bool = false
    @Published var transcribedText: String = ""
    @Published var errorMessage: String?
    @Published var currentFileName: String?
    
    private init() {}
    
    func transcribeFile(url: URL) {
        guard !isTranscribing else { return }
        
        isTranscribing = true
        errorMessage = nil
        transcribedText = ""
        currentFileName = url.lastPathComponent
        
        NotificationManager.shared.requestAuthorization()
        
        let duration = getAudioDuration(url: url)
        
        convertTo16kHzWav(sourceURL: url) { [weak self] conversionResult in
            switch conversionResult {
            case .success(let wavURL):
                WhisperManager.shared.transcribe(audioURL: wavURL, mode: .transcriptionOnly) { result in
                    DispatchQueue.main.async {
                        self?.isTranscribing = false
                        self?.currentFileName = nil
                        
                        // Clean up the temporary wav file
                        try? FileManager.default.removeItem(at: wavURL)
                        
                        switch result {
                        case .success(let text):
                            let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                            self?.transcribedText = cleanedText
                            
                            if !cleanedText.isEmpty {
                                TranscriptionHistoryManager.shared.addTranscription(cleanedText, duration: duration)
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
                }
            }
        }
    }
    
    func clearResult() {
        transcribedText = ""
        errorMessage = nil
    }
    
    private func getAudioDuration(url: URL) -> TimeInterval {
        let asset = AVURLAsset(url: url)
        return CMTimeGetSeconds(asset.duration)
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
