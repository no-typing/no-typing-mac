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
    
    /// Combines multiple audio files (one per host/speaker) into a single mono mix
    /// by concatenating them sequentially on the timeline.
    /// Each input track is placed one after the other so the full length of every host's
    /// audio is included. The combined output is an m4a suitable for Whisper transcription.
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
        guard let compositionTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            completion(.failure(CombineError.exportFailed("Could not create composition track.")))
            return
        }
        
        // Insert each track sequentially — advance cursor by each track's duration
        var cursor = CMTime.zero
        for (index, trackURL) in trackURLs.enumerated() {
            let asset = AVURLAsset(url: trackURL)
            guard let audioTrack = asset.tracks(withMediaType: .audio).first else {
                completion(.failure(CombineError.trackReadFailed("No audio in track \(index + 1): \(trackURL.lastPathComponent)")))
                return
            }
            
            let duration = asset.duration
            let timeRange = CMTimeRange(start: .zero, duration: duration)
            
            do {
                try compositionTrack.insertTimeRange(timeRange, of: audioTrack, at: cursor)
                cursor = CMTimeAdd(cursor, duration)
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
    
    /// Transcribes each track individually and produces a [Speaker Name] labeled output.
    func combineAndTranscribe(trackURLs: [URL], speakerNames: [String] = []) {
        FileTranscriptionManager.shared.transcribePodcastTracks(trackURLs, speakerNames: speakerNames)
    }
}
