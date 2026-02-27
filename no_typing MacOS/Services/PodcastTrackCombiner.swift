import Foundation
import AVFoundation

class PodcastTrackCombiner {
    static let shared = PodcastTrackCombiner()
    private init() {}
    
    enum CombineError: Error, LocalizedError {
        case noTracks
        case exportFailed(String)
        case trackReadFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .noTracks: return "No audio tracks provided."
            case .exportFailed(let msg): return "Export failed: \(msg)"
            case .trackReadFailed(let msg): return "Track read failed: \(msg)"
            }
        }
    }
    
    /// Combines multiple audio files (one per host/speaker) into a single stereo/mono mix.
    /// Each input track is assumed to be a separate host recording from the same session.
    /// The combined output is a 16kHz mono WAV suitable for Whisper transcription.
    func combineTracksToMono(trackURLs: [URL], completion: @escaping (Result<URL, Error>) -> Void) {
        guard !trackURLs.isEmpty else {
            completion(.failure(CombineError.noTracks))
            return
        }
        
        // If only one track, just return it directly
        if trackURLs.count == 1 {
            completion(.success(trackURLs[0]))
            return
        }
        
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("podcast_combined_\(UUID().uuidString).m4a")
        
        let composition = AVMutableComposition()
        
        for (index, trackURL) in trackURLs.enumerated() {
            let asset = AVURLAsset(url: trackURL)
            guard let audioTrack = asset.tracks(withMediaType: .audio).first else {
                completion(.failure(CombineError.trackReadFailed("No audio in track \(index + 1): \(trackURL.lastPathComponent)")))
                return
            }
            
            guard let compositionTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                completion(.failure(CombineError.trackReadFailed("Failed to create composition track for \(trackURL.lastPathComponent)")))
                return
            }
            
            do {
                let duration = asset.duration
                let timeRange = CMTimeRange(start: .zero, duration: duration)
                try compositionTrack.insertTimeRange(timeRange, of: audioTrack, at: .zero)
            } catch {
                completion(.failure(CombineError.trackReadFailed("Insert failed for track \(index + 1): \(error.localizedDescription)")))
                return
            }
        }
        
        // Export the composition
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            completion(.failure(CombineError.exportFailed("Could not create export session.")))
            return
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        
        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                completion(.success(outputURL))
            case .failed:
                completion(.failure(CombineError.exportFailed(exportSession.error?.localizedDescription ?? "Unknown")))
            case .cancelled:
                completion(.failure(CombineError.exportFailed("Export cancelled.")))
            default:
                completion(.failure(CombineError.exportFailed("Unexpected status: \(exportSession.status.rawValue)")))
            }
        }
    }
    
    /// Combines tracks and then feeds the result into FileTranscriptionManager
    func combineAndTranscribe(trackURLs: [URL]) {
        combineTracksToMono(trackURLs: trackURLs) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let combinedURL):
                    FileTranscriptionManager.shared.transcribeFile(url: combinedURL)
                case .failure(let error):
                    FileTranscriptionManager.shared.errorMessage = "Podcast combine failed: \(error.localizedDescription)"
                }
            }
        }
    }
}
