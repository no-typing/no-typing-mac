import Foundation
import AppKit

class ExportManager {
    static let shared = ExportManager()
    
    private init() {}
    
    enum ExportFormat: String, CaseIterable {
        case txt = "Text (.txt)"
        case md = "Markdown (.md)"
        case srt = "Subtitles (.srt)"
        case vtt = "WebVTT (.vtt)"
        case csv = "Comma Separated Values (.csv)"
        case whisper = "Whisper Bundle (.whisper)"
        
        var fileExtension: String {
            switch self {
            case .txt: return "txt"
            case .md: return "md"
            case .srt: return "srt"
            case .vtt: return "vtt"
            case .csv: return "csv"
            case .whisper: return "whisper"
            }
        }
    }
    
    /// Presents a save panel and exports the given item to the selected format.
    func exportItem(_ item: TranscriptionHistoryItem, format: ExportFormat, completion: @escaping (Result<URL, Error>) -> Void) {
        // Handle .whisper bundle separately
        if format == .whisper {
            exportWhisperBundle(item, completion: completion)
            return
        }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = []
        savePanel.allowedFileTypes = [format.fileExtension]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.title = "Export Transcription"
        savePanel.message = "Choose a location to save your transcription."
        
        let dateString = item.formattedFullDate
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: ",", with: "")
        savePanel.nameFieldStringValue = "Transcription_\(dateString).\(format.fileExtension)"
        
        DispatchQueue.main.async {
            savePanel.begin { response in
                if response == .OK, let url = savePanel.url {
                    DispatchQueue.global(qos: .userInitiated).async {
                        do {
                            let content = self.generateContent(for: item, format: format)
                            try content.write(to: url, atomically: true, encoding: .utf8)
                            DispatchQueue.main.async {
                                completion(.success(url))
                            }
                        } catch {
                            DispatchQueue.main.async {
                                completion(.failure(error))
                            }
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "ExportManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Export canceled by user."])))
                    }
                }
            }
        }
    }
    
    // MARK: - .whisper Bundle Export
    
    private func exportWhisperBundle(_ item: TranscriptionHistoryItem, completion: @escaping (Result<URL, Error>) -> Void) {
        let savePanel = NSSavePanel()
        savePanel.allowedFileTypes = ["whisper"]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.title = "Export as .whisper Bundle"
        savePanel.message = "Save your transcription with the original audio."
        
        let dateString = item.formattedFullDate
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: ",", with: "")
        savePanel.nameFieldStringValue = "Transcription_\(dateString).whisper"
        
        DispatchQueue.main.async {
            savePanel.begin { response in
                if response == .OK, let bundleURL = savePanel.url {
                    DispatchQueue.global(qos: .userInitiated).async {
                        do {
                            let fm = FileManager.default
                            
                            // Remove existing directory if overwriting
                            if fm.fileExists(atPath: bundleURL.path) {
                                try fm.removeItem(at: bundleURL)
                            }
                            
                            // Create bundle directory
                            try fm.createDirectory(at: bundleURL, withIntermediateDirectories: true, attributes: nil)
                            
                            // Write transcript.json
                            let encoder = JSONEncoder()
                            encoder.dateEncodingStrategy = .iso8601
                            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                            let jsonData = try encoder.encode(item)
                            try jsonData.write(to: bundleURL.appendingPathComponent("transcript.json"))
                            
                            // Copy original audio if accessible via bookmark
                            if let bookmarkData = item.sourceMediaData {
                                var isStale = false
                                if let mediaURL = try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) {
                                    let didAccess = mediaURL.startAccessingSecurityScopedResource()
                                    let ext = mediaURL.pathExtension
                                    let destAudioURL = bundleURL.appendingPathComponent("audio.\(ext)")
                                    try fm.copyItem(at: mediaURL, to: destAudioURL)
                                    if didAccess { mediaURL.stopAccessingSecurityScopedResource() }
                                }
                            }
                            
                            DispatchQueue.main.async {
                                completion(.success(bundleURL))
                            }
                        } catch {
                            DispatchQueue.main.async {
                                completion(.failure(error))
                            }
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "ExportManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Export canceled by user."])))
                    }
                }
            }
        }
    }
    
    // MARK: - .whisper Bundle Import
    
    func importWhisperBundle(at bundleURL: URL) throws -> TranscriptionHistoryItem {
        let transcriptURL = bundleURL.appendingPathComponent("transcript.json")
        let data = try Data(contentsOf: transcriptURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var item = try decoder.decode(TranscriptionHistoryItem.self, from: data)
        
        // Re-attach audio bookmark if an audio file exists in the bundle
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(at: bundleURL, includingPropertiesForKeys: nil)
        if let audioFile = contents.first(where: { $0.lastPathComponent.hasPrefix("audio.") }) {
            // Move audio to a stable location and create a new bookmark
            let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let mediaDir = appSupport.appendingPathComponent("NoTyping/ImportedMedia")
            try fm.createDirectory(at: mediaDir, withIntermediateDirectories: true)
            let destURL = mediaDir.appendingPathComponent(audioFile.lastPathComponent)
            if !fm.fileExists(atPath: destURL.path) {
                try fm.copyItem(at: audioFile, to: destURL)
            }
            item.sourceMediaData = try destURL.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        }
        
        return item
    }
    
    // MARK: - Content Generation
    
    private func generateContent(for item: TranscriptionHistoryItem, format: ExportFormat) -> String {
        switch format {
        case .txt:
            return generateText(item)
        case .md:
            return generateMarkdown(item)
        case .srt:
            return generateSRT(item)
        case .vtt:
            return generateVTT(item)
        case .csv:
            return generateCSV(item)
        case .whisper:
            return "" // Handled separately by exportWhisperBundle
        }
    }
    
    private func generateText(_ item: TranscriptionHistoryItem) -> String {
        guard let segments = item.segments, !segments.isEmpty else {
            return item.text
        }
        var txt = ""
        for segment in segments {
            if let speaker = segment.speaker, !speaker.isEmpty {
                txt += "[\(speaker)]: "
            }
            txt += "\(segment.text.trimmingCharacters(in: .whitespacesAndNewlines))\n\n"
        }
        return txt.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func generateMarkdown(_ item: TranscriptionHistoryItem) -> String {
        var md = "# Transcription\n\n"
        md += "**Date:** \(item.formattedFullDate)\n"
        if let duration = item.duration {
            md += "**Duration:** \(formatDuration(duration))\n"
        }
        md += "\n---\n\n"
        guard let segments = item.segments, !segments.isEmpty else {
            md += item.text
            return md
        }
        for segment in segments {
            if let speaker = segment.speaker, !speaker.isEmpty {
                md += "**\(speaker):** "
            }
            md += "\(segment.text.trimmingCharacters(in: .whitespacesAndNewlines))\n\n"
        }
        return md
    }
    
    private func generateSRT(_ item: TranscriptionHistoryItem) -> String {
        guard let segments = item.segments, !segments.isEmpty else {
            // Fallback if no timestamps exist
            return "1\n00:00:00,000 --> 00:00:10,000\n\(item.text)\n"
        }
        
        var srt = ""
        for (index, segment) in segments.enumerated() {
            srt += "\(index + 1)\n"
            srt += "\(formatTimestamp(segment.startTime, separator: ",")) --> \(formatTimestamp(segment.endTime, separator: ","))\n"
            if let speaker = segment.speaker, !speaker.isEmpty {
                srt += "[\(speaker)]: "
            }
            srt += "\(segment.text.trimmingCharacters(in: .whitespacesAndNewlines))\n\n"
        }
        return srt
    }
    
    private func generateVTT(_ item: TranscriptionHistoryItem) -> String {
        var vtt = "WEBVTT\n\n"
        
        guard let segments = item.segments, !segments.isEmpty else {
            // Fallback if no timestamps exist
            vtt += "00:00:00.000 --> 00:00:10.000\n\(item.text)\n"
            return vtt
        }
        
        for segment in segments {
            vtt += "\(formatTimestamp(segment.startTime, separator: ".")) --> \(formatTimestamp(segment.endTime, separator: "."))\n"
            if let speaker = segment.speaker, !speaker.isEmpty {
                vtt += "<v \(speaker)>"
            }
            vtt += "\(segment.text.trimmingCharacters(in: .whitespacesAndNewlines))\n\n"
        }
        return vtt
    }
    
    private func generateCSV(_ item: TranscriptionHistoryItem) -> String {
        var csv = "Speaker,Start Time,End Time,Text\n"
        
        guard let segments = item.segments, !segments.isEmpty else {
            // Fallback if no timestamps exist
            let escapedText = item.text.replacingOccurrences(of: "\"", with: "\"\"")
            csv += ",00:00:00,00:00:10,\"\(escapedText)\"\n"
            return csv
        }
        
        for segment in segments {
            let speaker = segment.speaker ?? ""
            let start = formatTimestamp(segment.startTime, separator: ".")
            let end = formatTimestamp(segment.endTime, separator: ".")
            // Escape quotes inside CSV strings
            let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "\"\"")
            csv += "\"\(speaker)\",\(start),\(end),\"\(text)\"\n"
        }
        
        return csv
    }
    
    // MARK: - Format Helpers
    
    private func formatTimestamp(_ timeInterval: TimeInterval, separator: String) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        let milliseconds = Int((timeInterval.truncatingRemainder(dividingBy: 1)) * 1000)
        
        return String(format: "%02d:%02d:%02d%@%03d", hours, minutes, seconds, separator, milliseconds)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%dh %02dm %02ds", hours, minutes, seconds)
        } else {
            return String(format: "%02dm %02ds", minutes, seconds)
        }
    }
}
