import Foundation

struct TranscriptionHistoryItem: Codable, Identifiable {
    let id: UUID
    var text: String
    var timestamp: Date
    var duration: TimeInterval?
    var segments: [WhisperTranscriptionSegment]?
    var wordCount: Int? = 0
    var timeOffset: TimeInterval? = 0
    var sourceMediaData: Data? = nil
    var sourceAppBundleID: String? = nil
    
    init(text: String, timestamp: Date = Date(), duration: TimeInterval? = nil, segments: [WhisperTranscriptionSegment]? = nil, wordCount: Int? = nil, timeOffset: TimeInterval? = 0, sourceMediaData: Data? = nil, sourceAppBundleID: String? = nil) {
        self.id = UUID()
        self.text = text
        self.timestamp = timestamp
        self.duration = duration
        self.segments = segments
        self.wordCount = wordCount ?? text.split { $0.isWhitespace || $0.isPunctuation }.count
        self.timeOffset = timeOffset
        self.sourceMediaData = sourceMediaData
        self.sourceAppBundleID = sourceAppBundleID
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    var formattedFullDate: String {
        let formatter = DateFormatter()
        
        let currentYear = Calendar.current.component(.year, from: Date())
        let itemYear = Calendar.current.component(.year, from: timestamp)
        
        if currentYear == itemYear {
            formatter.dateFormat = "EEE MMM dd - hh:mm a"
        } else {
            formatter.dateFormat = "EEE MMM dd, yyyy - hh:mm a"
        }
        
        return formatter.string(from: timestamp)
    }
}