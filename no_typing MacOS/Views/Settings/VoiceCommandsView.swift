import SwiftUI
import Foundation

struct VoiceCommandsView: View {
    @StateObject private var commandService = VoiceCommandService.shared
    @State private var showingEditSheet = false
    @State private var editingCommand: VoiceCommand? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Enable/Disable Toggle
            VStack(alignment: .leading, spacing: 16) {
                SettingsToggleRow(
                    icon: "mic.fill",
                    title: "Voice Commands",
                    isOn: $commandService.isEnabled,
                    iconGradient: LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .onChange(of: commandService.isEnabled) { enabled in
                    commandService.setEnabled(enabled)
                }
                
                Text("Perform keyboard actions when exactly speaking mapped keywords.")
                    .font(.system(size: 13))
                    .foregroundColor(ThemeColors.secondaryText)
                    .padding(.leading, 12)
            }
            
            if commandService.isEnabled {
                // Table Header
                HStack(spacing: 16) {
                    Text("Voice Command")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ThemeColors.secondaryText)
                        .frame(width: 140, alignment: .leading)
                    
                    Text("Action Performed")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ThemeColors.secondaryText)
                        .frame(width: 120, alignment: .leading)
                    
                    Text("Use Case")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ThemeColors.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, -8)
                
                // Commands List
                LazyVStack(spacing: 8) {
                    ForEach(commandService.commands) { command in
                        VoiceCommandRow(
                            command: command,
                            onEdit: { editingCommand = command }
                        )
                    }
                }
            }
        }
        .background(Color.clear)
        .sheet(item: $editingCommand) { command in
            VoiceCommandEditSheet(command: command) { updatedCommand in
                commandService.updateCommand(updatedCommand)
            }
        }
    }
}

struct VoiceCommandRow: View {
    let command: VoiceCommand
    let onEdit: () -> Void
    @State private var isHovered = false
    
    private var rowBackgroundColor: Color {
        Color.white.opacity(0.04)
    }
    
    private var rowBorderColor: Color {
        Color.white.opacity(0.08)
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // Trigger words
            HStack(spacing: 4) {
                Text(command.triggerWords.map { "\"\($0.capitalized)\"" }.joined(separator: " / "))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: 140, alignment: .leading)
            
            // Action badge
            Text(command.action.keyDescription)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.1))
                .cornerRadius(4)
                .frame(width: 120, alignment: .leading)
            
            // Description
            Text(command.action.description)
                .font(.system(size: 13))
                .foregroundColor(ThemeColors.secondaryText)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            // Edit button
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(isHovered ? Color.white.opacity(0.1) : Color.clear)
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .opacity(isHovered ? 1 : 0.6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(rowBackgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(rowBorderColor, lineWidth: 1)
        )
        .cornerRadius(8)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct VoiceCommandEditSheet: View {
    let command: VoiceCommand
    let onSave: (VoiceCommand) -> Void
    
    @State private var triggerText: String = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Edit Voice Command")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("Customize the trigger words that map to \(command.action.keyDescription)")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.secondary.opacity(0.1)))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                
                Divider()
                    .opacity(0.3)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Trigger Words (comma separated)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                
                TextField("e.g. oops, undo, mistake", text: $triggerText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
            
            Spacer()
            
            // Footer
            VStack(spacing: 0) {
                Divider()
                    .opacity(0.3)
                
                HStack(spacing: 12) {
                    Spacer()
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
                    .foregroundColor(.secondary)
                    .buttonStyle(PlainButtonStyle())
                    
                    Button("Save") {
                        save()
                    }
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.accentColor)
                    .cornerRadius(6)
                    .foregroundColor(.white)
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .background(colorScheme == .dark ? Color.black.opacity(0.02) : Color.white.opacity(0.8))
        }
        .frame(width: 480, height: 280)
        .background(colorScheme == .dark ? Color.black.opacity(0.95) : Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 8)
        .onAppear {
            triggerText = command.triggerWords.joined(separator: ", ")
        }
    }
    
    private func save() {
        let newTriggers = triggerText
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        guard !newTriggers.isEmpty else { return }
        
        var updatedCommand = command
        updatedCommand.triggerWords = newTriggers
        onSave(updatedCommand)
        dismiss()
    }
}
