import Foundation
import SwiftUI

class TranscriptionHistoryManager: ObservableObject {
    static let shared = TranscriptionHistoryManager()
    
    @Published var transcriptionHistory: [TranscriptionHistoryItem] = []
    
    // Insights stats
    @Published var wordsToday: Int = 0
    @Published var wordsThisWeek: Int = 0
    @Published var wordsAllTime: Int = 0
    
    // Time saved computed properties
    var timeSavedToday: String? { return formatTimeSaved(for: wordsToday) }
    var timeSavedThisWeek: String? { return formatTimeSaved(for: wordsThisWeek) }
    var timeSavedAllTime: String? { return formatTimeSaved(for: wordsAllTime) }
    
    /// Calculate estimated time saved assuming an average typing speed of 40 Words Per Minute.
    private func formatTimeSaved(for wordCount: Int) -> String? {
        guard wordCount > 0 else { return nil }
        
        let secondsSaved = Double(wordCount) / 40.0 * 60.0
        
        if secondsSaved < 60 {
            return "< 1m saved"
        }
        
        let minutes = Int(secondsSaved / 60)
        
        if minutes < 60 {
            return "~ \(minutes)m saved"
        }
        
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if remainingMinutes == 0 {
            return "~ \(hours)h saved"
        }
        
        return "~ \(hours)h \(remainingMinutes)m saved"
    }
    
    private let userDefaultsKey = "transcriptionHistory" // Keeping key for backward compatibility or migration if needed
    
    // File Storage properties
    private let storageQueue = DispatchQueue(label: "com.no_typing.transcriptionHistory", qos: .background)
    private var historyFileURL: URL {
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportURL = urls[0].appendingPathComponent("No-Typing", isDirectory: true)
        
        // Ensure directory exists
        if !FileManager.default.fileExists(atPath: appSupportURL.path) {
            try? FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        }
        
        return appSupportURL.appendingPathComponent("transcription_history.json")
    }
    
    // Keys for stats
    private let wordsTodayKey = "wordsSpokenToday"
    private let wordsThisWeekKey = "wordsSpokenThisWeek"
    private let wordsAllTimeKey = "wordsSpokenAllTime"
    private let lastUpdatedDateKey = "wordsLastUpdatedDate"
    
    private init() {
        loadHistory()
        loadAndRolloverStats()
    }
    
    func addTranscription(_ text: String, duration: TimeInterval? = nil, segments: [WhisperTranscriptionSegment]? = nil, sourceMediaData: Data? = nil, sourceAppBundleID: String? = nil) {
        // Don't add empty transcriptions
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let historyItem = TranscriptionHistoryItem(text: text, duration: duration, segments: segments, sourceMediaData: sourceMediaData, sourceAppBundleID: sourceAppBundleID)
        
        // Add to beginning of array
        transcriptionHistory.insert(historyItem, at: 0)
        
        // Allow up to 10,000 items before truncating to prevent infinite growth
        if transcriptionHistory.count > 10000 {
            transcriptionHistory = Array(transcriptionHistory.prefix(10000))
        }
        
        saveHistory()
        
        // Broadcast to Webhooks if enabled
        if let idString = UserDefaults.standard.string(forKey: "voiceWebhookEndpointId"),
           let endpointId = UUID(uuidString: idString) {
            WebhookManager.shared.sendTranscript(text: text, duration: duration, endpointId: endpointId)
        }
        
        // Update stats (Calculated independently of the array bounds)
        let words = text.split { $0.isWhitespace || $0.isNewline }.count
        if words > 0 {
            loadAndRolloverStats()
            
            wordsToday += words
            wordsThisWeek += words
            wordsAllTime += words
            
            let defaults = UserDefaults.standard
            defaults.set(wordsToday, forKey: wordsTodayKey)
            defaults.set(wordsThisWeek, forKey: wordsThisWeekKey)
            defaults.set(wordsAllTime, forKey: wordsAllTimeKey)
            defaults.set(Date(), forKey: lastUpdatedDateKey)
        }
        
        print("📝 Added transcription to history: \(text.prefix(50))...")
    }
    
    // MARK: - Update Item
    
    func updateTranscription(_ updatedItem: TranscriptionHistoryItem) {
        if let index = transcriptionHistory.firstIndex(where: { $0.id == updatedItem.id }) {
            transcriptionHistory[index] = updatedItem
            saveHistory()
            print("✏️ Updated transcription item: \(updatedItem.id)")
        }
    }
    
    // MARK: - Bulk Deletion
    
    func deleteTranscriptions(withIds ids: Set<UUID>) {
        transcriptionHistory.removeAll { ids.contains($0.id) }
        saveHistory()
        print("🗑️ Deleted \(ids.count) transcriptions.")
    }
    
    // MARK: - Storage Implementation
    
    private func loadHistory() {
        // First try to load from the new JSON file
        if FileManager.default.fileExists(atPath: historyFileURL.path) {
            do {
                let data = try Data(contentsOf: historyFileURL)
                let items = try JSONDecoder().decode([TranscriptionHistoryItem].self, from: data)
                self.transcriptionHistory = items
                print("📥 Loaded \(items.count) transcription history items from JSON")
                return
            } catch {
                print("❌ Failed to load history from JSON: \(error.localizedDescription)")
            }
        }
        
        // Fallback or Migration: Load from UserDefaults if JSON doesn't exist yet
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let items = try? JSONDecoder().decode([TranscriptionHistoryItem].self, from: data) {
            self.transcriptionHistory = items
            print("📥 Migrated \(items.count) transcription history items from UserDefaults")
            // Instantly save to JSON to complete migration
            saveHistory()
            return
        }
    }
    
    private func saveHistory() {
        // Make a thread-safe copy of the array for background serialization
        let itemsToSave = transcriptionHistory
        let fileURL = historyFileURL
        
        storageQueue.async {
            do {
                let encoded = try JSONEncoder().encode(itemsToSave)
                try encoded.write(to: fileURL, options: .atomic)
                print("💾 Saved \(itemsToSave.count) items to background JSON file")
            } catch {
                print("❌ Failed to save transcription history: \(error.localizedDescription)")
            }
        }
    }
    
    func clearHistory() {
        transcriptionHistory.removeAll()
        saveHistory()
        
        // Also wipe legacy UserDefaults if it exists
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        print("🗑️ Cleared transcription history")
    }
    
    private func loadAndRolloverStats() {
        let defaults = UserDefaults.standard
        let now = Date()
        let calendar = Calendar.current
        
        wordsAllTime = defaults.integer(forKey: wordsAllTimeKey)
        
        if let lastUpdateDate = defaults.object(forKey: lastUpdatedDateKey) as? Date {
            if !calendar.isDateInToday(lastUpdateDate) {
                wordsToday = 0
            } else {
                wordsToday = defaults.integer(forKey: wordsTodayKey)
            }
            
            if !calendar.isDate(lastUpdateDate, equalTo: now, toGranularity: .weekOfYear) {
                wordsThisWeek = 0
            } else {
                wordsThisWeek = defaults.integer(forKey: wordsThisWeekKey)
            }
        } else {
            wordsToday = 0
            wordsThisWeek = 0
            wordsAllTime = 0
        }
    }
}