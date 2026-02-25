import Foundation

struct TranscriptionHistoryItem: Codable, Identifiable {
    let id: UUID
    let text: String
    let timestamp: Date
    let duration: TimeInterval?
    
    init(text: String, timestamp: Date = Date(), duration: TimeInterval? = nil) {
        self.id = UUID()
        self.text = text
        self.timestamp = timestamp
        self.duration = duration
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