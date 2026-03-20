import Foundation
import Combine

class SpeakerManager: ObservableObject {
    static let shared = SpeakerManager()
    
    private let key = "podcast_speaker_names"
    
    @Published var speakers: [String] = []
    
    private init() {
        load()
    }
    
    func load() {
        speakers = UserDefaults.standard.stringArray(forKey: key) ?? []
    }
    
    func add(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !speakers.contains(trimmed) else { return }
        speakers.append(trimmed)
        save()
    }
    
    func remove(_ name: String) {
        speakers.removeAll { $0 == name }
        save()
    }
    
    private func save() {
        UserDefaults.standard.set(speakers, forKey: key)
    }
}
