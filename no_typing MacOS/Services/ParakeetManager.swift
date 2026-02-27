import Foundation

/// Manages inference for NVIDIA Parakeet models using ONNX runtime via a Python bridge.
/// Downloads ONNX models from HuggingFace and invokes inference through a bundled Python script.
class ParakeetManager {
    static let shared = ParakeetManager()
    private init() {}
    
    enum ParakeetError: Error, LocalizedError {
        case modelNotDownloaded
        case pythonNotAvailable
        case inferenceFailed(String)
        case outputParsingFailed
        
        var errorDescription: String? {
            switch self {
            case .modelNotDownloaded: return "Parakeet model is not downloaded yet."
            case .pythonNotAvailable: return "Python 3 is required to run Parakeet models. Install via Homebrew: brew install python3"
            case .inferenceFailed(let msg): return "Parakeet inference failed: \(msg)"
            case .outputParsingFailed: return "Failed to parse Parakeet transcription output."
            }
        }
    }
    
    /// Returns whether the given model ID is a Parakeet model
    static func isParakeetModel(_ modelId: String) -> Bool {
        return modelId.hasPrefix("parakeet_")
    }
    
    /// Returns the model directory for Parakeet
    private func getModelDirectory() -> URL {
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let modelDirectory = applicationSupport.appendingPathComponent("Whisper")
        return modelDirectory
    }
    
    /// Returns the ONNX model file path for a given model ID
    func modelFilePath(for modelId: String) -> URL {
        let fileName: String
        switch modelId {
        case "parakeet_v2": fileName = "parakeet-tdt-0.6b-v2.onnx"
        case "parakeet_v3": fileName = "parakeet-tdt-0.6b-v3.onnx"
        default: fileName = "parakeet-tdt-0.6b-v2.onnx"
        }
        return getModelDirectory().appendingPathComponent(fileName)
    }
    
    /// Check if model is available locally
    func isModelAvailable(modelId: String) -> Bool {
        return FileManager.default.fileExists(atPath: modelFilePath(for: modelId).path)
    }
    
    /// Run Parakeet inference on an audio file using onnx-asr Python package
    func transcribe(audioURL: URL, modelId: String, completion: @escaping (Result<[WhisperTranscriptionSegment], Error>) -> Void) {
        let modelPath = modelFilePath(for: modelId)
        
        guard FileManager.default.fileExists(atPath: modelPath.path) else {
            completion(.failure(ParakeetError.modelNotDownloaded))
            return
        }
        
        // Find python3
        let pythonPaths = ["/opt/homebrew/bin/python3", "/usr/local/bin/python3", "/usr/bin/python3"]
        guard let pythonPath = pythonPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            completion(.failure(ParakeetError.pythonNotAvailable))
            return
        }
        
        let processQueue = DispatchQueue(label: "com.no_typing.parakeet.inference", qos: .userInitiated)
        processQueue.async {
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("parakeet_\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let outputFile = tempDir.appendingPathComponent("output.json")
            
            // Create a Python script for inference
            let scriptContent = """
            import json, sys, os
            try:
                from onnx_asr import Transcriber
                transcriber = Transcriber(model_path=sys.argv[1])
                result = transcriber.transcribe(sys.argv[2])
                # Output JSON with segments
                segments = []
                if hasattr(result, 'segments'):
                    for seg in result.segments:
                        segments.append({
                            "start": seg.start,
                            "end": seg.end,
                            "text": seg.text
                        })
                else:
                    # Fallback: entire text as single segment
                    segments.append({
                        "start": 0.0,
                        "end": 0.0,
                        "text": str(result) if not isinstance(result, dict) else result.get("text", "")
                    })
                with open(sys.argv[3], 'w') as f:
                    json.dump({"segments": segments}, f)
            except ImportError:
                # Fallback: try nemo_toolkit
                try:
                    import nemo.collections.asr as nemo_asr
                    model = nemo_asr.models.ASRModel.restore_from(sys.argv[1])
                    text = model.transcribe([sys.argv[2]])
                    segments = [{"start": 0.0, "end": 0.0, "text": text[0] if isinstance(text, list) else str(text)}]
                    with open(sys.argv[3], 'w') as f:
                        json.dump({"segments": segments}, f)
                except Exception as e:
                    print(f"ERROR: {e}", file=sys.stderr)
                    sys.exit(1)
            except Exception as e:
                print(f"ERROR: {e}", file=sys.stderr)
                sys.exit(1)
            """
            
            let scriptPath = tempDir.appendingPathComponent("parakeet_infer.py")
            try? scriptContent.write(to: scriptPath, atomically: true, encoding: .utf8)
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: pythonPath)
            process.arguments = [scriptPath.path, modelPath.path, audioURL.path, outputFile.path]
            process.currentDirectoryURL = tempDir
            
            let errorPipe = Pipe()
            process.standardError = errorPipe
            process.standardOutput = Pipe() // Suppress stdout
            
            do {
                try process.run()
                process.waitUntilExit()
                
                if process.terminationStatus != 0 {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    
                    // Clean up
                    try? FileManager.default.removeItem(at: tempDir)
                    
                    DispatchQueue.main.async {
                        completion(.failure(ParakeetError.inferenceFailed(errorMsg)))
                    }
                    return
                }
                
                // Parse the output JSON
                let outputData = try Data(contentsOf: outputFile)
                let decoded = try JSONDecoder().decode(ParakeetOutput.self, from: outputData)
                
                let segments = decoded.segments.map { seg in
                    WhisperTranscriptionSegment(
                        startTime: seg.start,
                        endTime: seg.end,
                        text: seg.text,
                        translatedText: nil,
                        speaker: nil,
                        isStarred: false
                    )
                }
                
                // Clean up
                try? FileManager.default.removeItem(at: tempDir)
                
                DispatchQueue.main.async {
                    completion(.success(segments))
                }
            } catch {
                try? FileManager.default.removeItem(at: tempDir)
                DispatchQueue.main.async {
                    completion(.failure(ParakeetError.inferenceFailed(error.localizedDescription)))
                }
            }
        }
    }
}

// MARK: - Parakeet Output Models
private struct ParakeetOutput: Codable {
    let segments: [ParakeetSegment]
}

private struct ParakeetSegment: Codable {
    let start: Double
    let end: Double
    let text: String
}
