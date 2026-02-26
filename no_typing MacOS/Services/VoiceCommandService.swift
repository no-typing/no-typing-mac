import Foundation

enum CommandAction: String, Codable, CaseIterable, Identifiable {
    case `return` = "Return"
    case tab = "Tab"
    case undo = "Undo"
    case newLine = "New Line"
    case selectAll = "Select All"
    case clear = "Clear"
    
    var id: String { self.rawValue }
    
    var description: String {
        switch self {
        case .return: return "Slack, Discord, iMessage, Email."
        case .tab: return "Filling out web forms or spreadsheets."
        case .undo: return "Deletes the last transcription if it was wrong."
        case .newLine: return "Creates space without sending the message."
        case .selectAll: return "Quickly highlight text for formatting."
        case .clear: return "Selects and deletes all text in the input."
        }
    }
    
    var keyDescription: String {
        switch self {
        case .return: return "Key: Return"
        case .tab: return "Key: Tab"
        case .undo: return "Cmd + Z"
        case .newLine: return "Shift + Return"
        case .selectAll: return "Cmd + A"
        case .clear: return "Cmd + A, Delete"
        }
    }
}

struct VoiceCommand: Identifiable, Codable, Equatable {
    var id: UUID
    var triggerWords: [String]
    var action: CommandAction
    var enabled: Bool
    
    init(id: UUID = UUID(), triggerWords: [String], action: CommandAction, enabled: Bool = true) {
        self.id = id
        self.triggerWords = triggerWords
        self.action = action
        self.enabled = enabled
    }
}

class VoiceCommandService: ObservableObject {
    static let shared = VoiceCommandService()
    
    @Published var commands: [VoiceCommand] = []
    @Published var isEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "voiceCommandsEnabled")
        }
    }
    
    private let storageKey = "voiceCommands"
    
    private init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: "voiceCommandsEnabled")
        
        // If it's the first launch or not set, default to true
        if UserDefaults.standard.object(forKey: "voiceCommandsEnabled") == nil {
            self.isEnabled = true
            UserDefaults.standard.set(true, forKey: "voiceCommandsEnabled")
        }
        
        loadCommands()
    }
    
    private func loadCommands() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let savedCommands = try? JSONDecoder().decode([VoiceCommand].self, from: data) {
            self.commands = savedCommands
        } else {
            // Default commands matching the specifications
            self.commands = [
                VoiceCommand(triggerWords: ["submit", "send", "enter"], action: .return),
                VoiceCommand(triggerWords: ["next"], action: .tab),
                VoiceCommand(triggerWords: ["oops", "undo"], action: .undo),
                VoiceCommand(triggerWords: ["new line"], action: .newLine),
                VoiceCommand(triggerWords: ["select all"], action: .selectAll),
                VoiceCommand(triggerWords: ["clear"], action: .clear)
            ]
            saveCommands()
        }
    }
    
    private func saveCommands() {
        if let data = try? JSONEncoder().encode(commands) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    func addCommand(_ command: VoiceCommand) {
        commands.append(command)
        saveCommands()
    }
    
    func updateCommand(_ command: VoiceCommand) {
        if let index = commands.firstIndex(where: { $0.id == command.id }) {
            commands[index] = command
            saveCommands()
        }
    }
    
    func removeCommand(_ command: VoiceCommand) {
        commands.removeAll { $0.id == command.id }
        saveCommands()
    }
    
    func setEnabled(_ enabled: Bool) {
        self.isEnabled = enabled
    }
    
    /// Evaluates exact match (ignoring case, punctuation, and whitespace)
    func evaluate(text: String) -> CommandAction? {
        guard isEnabled else { return nil }
        
        let cleanedText = normalize(text)
        
        for command in commands where command.enabled {
            for word in command.triggerWords {
                if cleanedText == normalize(word) {
                    return command.action
                }
            }
        }
        return nil
    }
    
    /// Normalizes text by removing all punctuation and extra whitespace
    private func normalize(_ text: String) -> String {
        return text.lowercased()
            .components(separatedBy: CharacterSet.punctuationCharacters)
            .joined(separator: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
}
