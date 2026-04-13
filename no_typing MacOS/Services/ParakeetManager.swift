import Foundation
import AVFAudio

/// Manages inference for NVIDIA Parakeet models using sherpa-onnx CLI binary.
/// Downloads model archives from GitHub releases and invokes the bundled sherpa-onnx-offline binary.
class ParakeetManager {
    static let shared = ParakeetManager()
    private init() {}
    
    enum ParakeetError: Error, LocalizedError {
        case modelNotDownloaded
        case sherpaOnnxNotAvailable
        case inferenceFailed(String)
        case outputParsingFailed
        case extractionFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .modelNotDownloaded: return "Parakeet model is not downloaded yet."
            case .sherpaOnnxNotAvailable: return "sherpa-onnx-offline binary not found in app bundle. Please re-install the application."
            case .inferenceFailed(let msg): return "Parakeet inference failed: \(msg)"
            case .outputParsingFailed: return "Failed to parse Parakeet transcription output."
            case .extractionFailed(let msg): return "Failed to extract model archive: \(msg)"
            }
        }
    }
    
    // MARK: - Model Info
    
    struct ModelConfig {
        let archiveName: String
        let downloadURL: String
        let directoryName: String
    }
    
    static let modelConfigs: [String: ModelConfig] = [
        "parakeet_v2": ModelConfig(
            archiveName: "sherpa-onnx-nemo-parakeet-tdt-0.6b-v2-int8.tar.bz2",
            downloadURL: "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-nemo-parakeet-tdt-0.6b-v2-int8.tar.bz2",
            directoryName: "sherpa-onnx-nemo-parakeet-tdt-0.6b-v2-int8"
        ),
        "parakeet_v3": ModelConfig(
            archiveName: "sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8.tar.bz2",
            downloadURL: "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8.tar.bz2",
            directoryName: "sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8"
        )
    ]
    
    /// Returns whether the given model ID is a Parakeet model
    static func isParakeetModel(_ modelId: String, customFileName: String? = nil) -> Bool {
        if modelId.hasPrefix("parakeet_") { return true }
        if let fn = customFileName { return fn.hasSuffix(".tar.bz2") }
        // Fallback (may crash if WhisperManager is uninitialized)
        if let custom = WhisperManager.shared.customModels.first(where: { $0.id == modelId }) {
            return custom.fileName.hasSuffix(".tar.bz2")
        }
        return false
    }
    
    /// Returns the model directory root in Application Support
    private func getModelDirectory() -> URL {
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let modelDirectory = applicationSupport.appendingPathComponent("Whisper")
        return modelDirectory
    }
    
    /// Returns the extracted model directory for a given model ID
    func modelDirectoryPath(for modelId: String, customFileName: String? = nil) -> URL {
        if let config = Self.modelConfigs[modelId] {
            return getModelDirectory().appendingPathComponent(config.directoryName)
        }
        
        let resolveFileName: String? = customFileName ?? WhisperManager.shared.customModels.first(where: { $0.id == modelId })?.fileName
        
        if let fileName = resolveFileName, fileName.hasSuffix(".tar.bz2") {
             let directoryName = String(fileName.dropLast(8))
             return getModelDirectory().appendingPathComponent(directoryName)
        }
        return getModelDirectory().appendingPathComponent("parakeet-unknown")
    }
    
    /// Check if model is available locally (extracted directory with required files)
    func isModelAvailable(modelId: String, customFileName: String? = nil) -> Bool {
        let modelDir = modelDirectoryPath(for: modelId, customFileName: customFileName)
        let fm = FileManager.default
        let items = (try? fm.contentsOfDirectory(atPath: modelDir.path)) ?? []
        let hasTokens = items.contains(where: { $0.hasSuffix("tokens.txt") })
        guard hasTokens else { return false }
        
        return items.contains(where: { $0.hasSuffix(".onnx") })
    }
    
    /// Check if sherpa-onnx-offline binary is available in the bundle
    func isSherpaOnnxAvailable() -> Bool {
        return getSherpaOnnxURL() != nil
    }
    
    /// Get the path to the bundled sherpa-onnx-offline binary
    private func getSherpaOnnxURL() -> URL? {
        // First check standard executable path (Contents/MacOS/sherpa-onnx-offline)
        if let execURL = Bundle.main.url(forAuxiliaryExecutable: "sherpa-onnx-offline") {
            if FileManager.default.fileExists(atPath: execURL.path) {
                return execURL
            }
        }
        
        // Fallback to Resources
        return Bundle.main.url(forResource: "sherpa-onnx-offline", withExtension: nil)
    }
    
    /// Returns a human-readable requirements string for the UI
    static var requirementsDescription: String {
        return "Powered by Sherpa-ONNX (M-series Mac recommended)"
    }
    
    // MARK: - Archive Extraction
    
    /// Extract a downloaded tar.bz2 archive to the model directory
    func extractModelArchive(archivePath: URL, modelId: String) throws {
        let directoryName: String
        if let config = Self.modelConfigs[modelId] {
            directoryName = config.directoryName
        } else {
            let fileName = archivePath.lastPathComponent
            if fileName.hasSuffix(".tar.bz2") {
                directoryName = String(fileName.dropLast(8))
            } else {
                throw ParakeetError.extractionFailed("Custom model archive must be a .tar.bz2 file.")
            }
        }
        
        let destinationDir = getModelDirectory()
        let extractedDir = destinationDir.appendingPathComponent(directoryName)
        
        // Remove existing extracted directory if present
        if FileManager.default.fileExists(atPath: extractedDir.path) {
            try FileManager.default.removeItem(at: extractedDir)
        }
        
        // Extract using tar command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-xjf", archivePath.path, "-C", destinationDir.path]
        process.standardOutput = Pipe()
        
        let errorPipe = Pipe()
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown extraction error"
            throw ParakeetError.extractionFailed(errorMsg)
        }
        
        // Verify extraction produced the expected files
        guard isModelAvailable(modelId: modelId) else {
            throw ParakeetError.extractionFailed("Expected model files not found after extraction in \(directoryName)")
        }
        
        // Clean up the archive file
        try? FileManager.default.removeItem(at: archivePath)
    }
    
    // MARK: - Transcription
    
    /// Run Parakeet inference on an audio file using sherpa-onnx-offline CLI
    func transcribe(audioURL: URL, modelId: String, completion: @escaping (Result<[WhisperTranscriptionSegment], Error>) -> Void) {
        guard isModelAvailable(modelId: modelId) else {
            completion(.failure(ParakeetError.modelNotDownloaded))
            return
        }
        
        guard let sherpaURL = getSherpaOnnxURL() else {
            completion(.failure(ParakeetError.sherpaOnnxNotAvailable))
            return
        }
        
        // Standardize and chunk audio to avoid ONNX max sequence length crash on long files
        splitAndStandardizeAudio(sourceURL: audioURL, chunkDuration: 60.0) { result in
            switch result {
            case .success(let chunkURLs):
                self.runSherpaOnnxOnChunks(chunkURLs: chunkURLs, modelId: modelId, sherpaURL: sherpaURL, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func runSherpaOnnxOnChunks(chunkURLs: [URL], modelId: String, sherpaURL: URL, completion: @escaping (Result<[WhisperTranscriptionSegment], Error>) -> Void) {
        let modelDir = modelDirectoryPath(for: modelId)
        
        var allText = [String]()
        
        for chunkURL in chunkURLs {
            let result = runSherpaOnnxSync(audioURL: chunkURL, sherpaURL: sherpaURL, modelDir: modelDir)
            switch result {
            case .success(let text):
                if !text.isEmpty { allText.append(text) }
            case .failure(let error):
                // Clean up temp chunks
                chunkURLs.forEach { try? FileManager.default.removeItem(at: $0) }
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
        }
        
        // Clean up temp chunks
        chunkURLs.forEach { try? FileManager.default.removeItem(at: $0) }
        
        let fullText = allText.joined(separator: " ")
        if fullText.isEmpty {
            DispatchQueue.main.async { completion(.failure(ParakeetError.outputParsingFailed)) }
            return
        }
        let segment = WhisperTranscriptionSegment(startTime: 0, endTime: 0, text: fullText, translatedText: nil, speaker: nil, isStarred: false)
        DispatchQueue.main.async { completion(.success([segment])) }
    }

    private func runSherpaOnnxSync(audioURL: URL, sherpaURL: URL, modelDir: URL) -> Result<String, Error> {
        let fm = FileManager.default
        let items = (try? fm.contentsOfDirectory(atPath: modelDir.path)) ?? []
        
        guard let tokensFile = items.first(where: { $0.hasSuffix("tokens.txt") }) else {
            return .failure(ParakeetError.inferenceFailed("Missing tokens.txt file"))
        }
        let tokensPath = modelDir.appendingPathComponent(tokensFile).path
        
        var args = [
            "--tokens=\(tokensPath)",
            "--num-threads=4",
            "--sample-rate=16000",
            "--decoding-method=greedy_search"
        ]
        
        // Find architecture specific ONNX files
        let encoder = items.first(where: { $0.contains("encoder") })
        let decoder = items.first(where: { $0.contains("decoder") })
        let joiner = items.first(where: { $0.contains("joiner") })
        
        let nemoCTC = items.first(where: { $0.hasPrefix("model") && $0.hasSuffix(".onnx") })
        
        if let e = encoder, let d = decoder, let j = joiner {
            // Transducer models (Parakeet, Zipformer)
            args.append("--encoder=\(modelDir.appendingPathComponent(e).path)")
            args.append("--decoder=\(modelDir.appendingPathComponent(d).path)")
            args.append("--joiner=\(modelDir.appendingPathComponent(j).path)")
            let featDim = (modelDir.path.lowercased().contains("parakeet") || e.lowercased().contains("parakeet")) ? "128" : "80"
            args.append("--feat-dim=\(featDim)")
        } else if let e = encoder, let d = decoder {
            // Whisper models have an encoder and decoder but NO joiner
            args.append("--whisper-encoder=\(modelDir.appendingPathComponent(e).path)")
            args.append("--whisper-decoder=\(modelDir.appendingPathComponent(d).path)")
        } else if let n = nemoCTC {
            args.append("--nemo-ctc=\(modelDir.appendingPathComponent(n).path)")
        }
        
        args.append(audioURL.path)
        
        let process = Process()
        process.executableURL = sherpaURL
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            if process.terminationStatus != 0 {
                return .failure(ParakeetError.inferenceFailed(output))
            }
            return .success(parseSherpaOutput(output))
        } catch {
            return .failure(error)
        }
    }

    private func runSherpaOnnx(audioURL: URL, modelId: String, sherpaURL: URL, completion: @escaping (Result<[WhisperTranscriptionSegment], Error>) -> Void) {
        let modelDir = modelDirectoryPath(for: modelId)
        let encoder = modelDir.appendingPathComponent("encoder.int8.onnx")
        let decoder = modelDir.appendingPathComponent("decoder.int8.onnx")
        let joiner = modelDir.appendingPathComponent("joiner.int8.onnx")
        let tokens = modelDir.appendingPathComponent("tokens.txt")
        
        let processQueue = DispatchQueue(label: "com.no-typing.parakeet.inference", qos: .userInitiated)
        processQueue.async {
            let process = Process()
            process.executableURL = sherpaURL
            process.arguments = [
                "--encoder=\(encoder.path)",
                "--decoder=\(decoder.path)",
                "--joiner=\(joiner.path)",
                "--tokens=\(tokens.path)",
                "--num-threads=4",
                "--feat-dim=128",
                "--sample-rate=16000",
                "--decoding-method=greedy_search",
                audioURL.path
            ]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8) ?? ""
                
                if process.terminationStatus != 0 {
                    DispatchQueue.main.async {
                        completion(.failure(ParakeetError.inferenceFailed(output)))
                    }
                    return
                }
                
                // sherpa-onnx-offline outputs a JSON string describing the transcription
                let transcribedText = self.parseSherpaOutput(output)
                
                if transcribedText.isEmpty {
                    DispatchQueue.main.async {
                        completion(.failure(ParakeetError.outputParsingFailed))
                    }
                    return
                }
                
                // Create a single segment with the full text
                let segment = WhisperTranscriptionSegment(
                    startTime: 0.0,
                    endTime: 0.0,
                    text: transcribedText,
                    translatedText: nil,
                    speaker: nil,
                    isStarred: false
                )
                
                DispatchQueue.main.async {
                    completion(.success([segment]))
                }
                
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Format Standardization & Chunking
    
    private static let chunkSampleRate: Double = 16000

    /// Split audio into standard PCM chunks of `chunkDuration` seconds each.
    private func splitAndStandardizeAudio(sourceURL: URL, chunkDuration: Double, completion: @escaping (Result<[URL], Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let file = try AVAudioFile(forReading: sourceURL)
                let sourceSampleRate = file.processingFormat.sampleRate
                let sourceFormat = file.processingFormat
                
                guard let outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                                       sampleRate: Self.chunkSampleRate,
                                                       channels: 1,
                                                       interleaved: false) else {
                    completion(.failure(NSError(domain: "ParakeetManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create output format"])))
                    return
                }
                
                guard let converter = AVAudioConverter(from: sourceFormat, to: outputFormat) else {
                    completion(.failure(NSError(domain: "ParakeetManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create converter"])))
                    return
                }
                
                // Read all frames into a single input buffer
                let totalFrames = AVAudioFrameCount(file.length)
                guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: totalFrames) else {
                    completion(.failure(NSError(domain: "ParakeetManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to allocate input buffer"])))
                    return
                }
                try file.read(into: inputBuffer)
                
                // Convert the full audio to target format
                let outputFrameCapacity = AVAudioFrameCount(Double(totalFrames) * (Self.chunkSampleRate / sourceSampleRate))
                guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputFrameCapacity) else {
                    completion(.failure(NSError(domain: "ParakeetManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to allocate output buffer"])))
                    return
                }
                
                var convError: NSError?
                let status = converter.convert(to: outputBuffer, error: &convError) { _, outStatus in
                    outStatus.pointee = .haveData
                    return inputBuffer
                }
                if let err = convError { completion(.failure(err)); return }
                if status == .error {
                    completion(.failure(NSError(domain: "ParakeetManager", code: 5, userInfo: [NSLocalizedDescriptionKey: "Conversion failed"])))
                    return
                }
                
                guard let channelData = outputBuffer.int16ChannelData else {
                    completion(.failure(NSError(domain: "ParakeetManager", code: 6, userInfo: [NSLocalizedDescriptionKey: "No channel data"])))
                    return
                }
                
                let totalOutputFrames = Int(outputBuffer.frameLength)
                let framesPerChunk = Int(Self.chunkSampleRate * chunkDuration)
                let tempDir = FileManager.default.temporaryDirectory
                var chunkURLs = [URL]()
                var offset = 0
                var chunkIndex = 0
                
                while offset < totalOutputFrames {
                    let count = min(framesPerChunk, totalOutputFrames - offset)
                    let dataSize = UInt32(count) * 2
                    var pcmData = Data()
                    pcmData.append(contentsOf: "RIFF".utf8)
                    var fileSize = dataSize + 36; pcmData.append(Data(bytes: &fileSize, count: 4))
                    pcmData.append(contentsOf: "WAVE".utf8)
                    pcmData.append(contentsOf: "fmt ".utf8)
                    var fmtSize: UInt32 = 16; pcmData.append(Data(bytes: &fmtSize, count: 4))
                    var fmtTag: UInt16 = 1; pcmData.append(Data(bytes: &fmtTag, count: 2))
                    var channels: UInt16 = 1; pcmData.append(Data(bytes: &channels, count: 2))
                    var sr: UInt32 = UInt32(Self.chunkSampleRate); pcmData.append(Data(bytes: &sr, count: 4))
                    var byteRate: UInt32 = UInt32(Self.chunkSampleRate) * 2; pcmData.append(Data(bytes: &byteRate, count: 4))
                    var blockAlign: UInt16 = 2; pcmData.append(Data(bytes: &blockAlign, count: 2))
                    var bps: UInt16 = 16; pcmData.append(Data(bytes: &bps, count: 2))
                    pcmData.append(contentsOf: "data".utf8)
                    var ds = dataSize; pcmData.append(Data(bytes: &ds, count: 4))
                    let rawPtr = UnsafeRawBufferPointer(start: channelData[0].advanced(by: offset), count: count * 2)
                    pcmData.append(contentsOf: rawPtr)
                    let chunkURL = tempDir.appendingPathComponent("parakeet_chunk_\(chunkIndex)_\(UUID().uuidString).wav")
                    try pcmData.write(to: chunkURL)
                    chunkURLs.append(chunkURL)
                    offset += count
                    chunkIndex += 1
                }
                
                completion(.success(chunkURLs))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// (Legacy) Converts entire file without chunking — kept for compatibility.
    private func standardizeAudioForParakeet(sourceURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        let tempDir = FileManager.default.temporaryDirectory
        let outputURL = tempDir.appendingPathComponent("parakeet_std_\(UUID().uuidString).wav")
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let file = try AVAudioFile(forReading: sourceURL)
                let format = file.processingFormat
                
                guard let outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                                       sampleRate: 16000,
                                                       channels: 1,
                                                       interleaved: false) else {
                    completion(.failure(NSError(domain: "ParakeetManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create output audio format"])))
                    return
                }
                
                guard let converter = AVAudioConverter(from: format, to: outputFormat) else {
                    completion(.failure(NSError(domain: "ParakeetManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio converter"])))
                    return
                }
                
                let frameCapacity = AVAudioFrameCount(file.length)
                guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
                    completion(.failure(NSError(domain: "ParakeetManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to allocate input buffer"])))
                    return
                }
                
                try file.read(into: inputBuffer)
                
                let outputFrameCapacity = AVAudioFrameCount(Double(frameCapacity) * (outputFormat.sampleRate / format.sampleRate))
                guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputFrameCapacity) else {
                    completion(.failure(NSError(domain: "ParakeetManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to allocate output buffer"])))
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
                    completion(.failure(NSError(domain: "ParakeetManager", code: 5, userInfo: [NSLocalizedDescriptionKey: "Conversion failed"])))
                    return
                }
                
                // Construct standard WAV header manually to bypass Extensible generation in AVAudioFile
                let frameLength = outputBuffer.frameLength
                guard let channelData = outputBuffer.int16ChannelData else {
                    completion(.failure(NSError(domain: "ParakeetManager", code: 6, userInfo: [NSLocalizedDescriptionKey: "Failed to get PCM data from buffer"])))
                    return
                }
                
                let dataSize = UInt32(frameLength) * 2
                var pcmData = Data()
                
                pcmData.append(contentsOf: "RIFF".utf8)
                var fileSize = dataSize + 36
                pcmData.append(Data(bytes: &fileSize, count: 4))
                pcmData.append(contentsOf: "WAVE".utf8)
                pcmData.append(contentsOf: "fmt ".utf8)
                
                var fmtSize: UInt32 = 16
                pcmData.append(Data(bytes: &fmtSize, count: 4))
                var formatTag: UInt16 = 1
                pcmData.append(Data(bytes: &formatTag, count: 2))
                var channels: UInt16 = 1
                pcmData.append(Data(bytes: &channels, count: 2))
                var sampleRate: UInt32 = 16000
                pcmData.append(Data(bytes: &sampleRate, count: 4))
                var byteRate: UInt32 = 16000 * 2
                pcmData.append(Data(bytes: &byteRate, count: 4))
                var blockAlign: UInt16 = 2
                pcmData.append(Data(bytes: &blockAlign, count: 2))
                var bitsPerSample: UInt16 = 16
                pcmData.append(Data(bytes: &bitsPerSample, count: 2))
                
                pcmData.append(contentsOf: "data".utf8)
                var customDataSize = dataSize
                pcmData.append(Data(bytes: &customDataSize, count: 4))
                
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
    
    /// Parse the sherpa-onnx-offline stdout output to extract transcription text
    private func parseSherpaOutput(_ output: String) -> String {
        // sherpa-onnx-offline prints lines but the actual translation is a JSON object.
        // E.g.: {"lang": "", "emotion": "", "event": "", "text": " Hello world", "timestamps": ...
        
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("{") && trimmed.hasSuffix("}") {
                // Try to parse this JSON payload
                if let data = trimmed.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let text = json["text"] as? String {
                    return text.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        return ""
    }
}
