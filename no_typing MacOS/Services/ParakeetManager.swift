import Foundation

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
    static func isParakeetModel(_ modelId: String) -> Bool {
        return modelId.hasPrefix("parakeet_")
    }
    
    /// Returns the model directory root in Application Support
    private func getModelDirectory() -> URL {
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let modelDirectory = applicationSupport.appendingPathComponent("Whisper")
        return modelDirectory
    }
    
    /// Returns the extracted model directory for a given model ID
    func modelDirectoryPath(for modelId: String) -> URL {
        guard let config = Self.modelConfigs[modelId] else {
            return getModelDirectory().appendingPathComponent("parakeet-unknown")
        }
        return getModelDirectory().appendingPathComponent(config.directoryName)
    }
    
    /// Check if model is available locally (extracted directory with required files)
    func isModelAvailable(modelId: String) -> Bool {
        let modelDir = modelDirectoryPath(for: modelId)
        let encoder = modelDir.appendingPathComponent("encoder.int8.onnx")
        let decoder = modelDir.appendingPathComponent("decoder.int8.onnx")
        let joiner = modelDir.appendingPathComponent("joiner.int8.onnx")
        let tokens = modelDir.appendingPathComponent("tokens.txt")
        
        let fm = FileManager.default
        return fm.fileExists(atPath: encoder.path) &&
               fm.fileExists(atPath: decoder.path) &&
               fm.fileExists(atPath: joiner.path) &&
               fm.fileExists(atPath: tokens.path)
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
        guard let config = Self.modelConfigs[modelId] else {
            throw ParakeetError.extractionFailed("Unknown model ID: \(modelId)")
        }
        
        let destinationDir = getModelDirectory()
        let extractedDir = destinationDir.appendingPathComponent(config.directoryName)
        
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
            throw ParakeetError.extractionFailed("Expected model files not found after extraction in \(config.directoryName)")
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
        
        let modelDir = modelDirectoryPath(for: modelId)
        let encoder = modelDir.appendingPathComponent("encoder.int8.onnx")
        let decoder = modelDir.appendingPathComponent("decoder.int8.onnx")
        let joiner = modelDir.appendingPathComponent("joiner.int8.onnx")
        let tokens = modelDir.appendingPathComponent("tokens.txt")
        
        let processQueue = DispatchQueue(label: "com.no_typing.parakeet.inference", qos: .userInitiated)
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
                let transcribedText = self.parseOutput(output)
                
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
                    completion(.failure(ParakeetError.inferenceFailed(error.localizedDescription)))
                }
            }
        }
    }
    
    /// Parse the sherpa-onnx-offline stdout output to extract transcription text
    private func parseOutput(_ output: String) -> String {
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
