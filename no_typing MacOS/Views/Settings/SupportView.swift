import SwiftUI

enum FeedbackType: String, CaseIterable, Identifiable {
    case bugReport = "Bug Report"
    case featureRequest = "Feature Request"
    case generalFeedback = "General Feedback"
    
    var id: String { self.rawValue }
}

struct SupportView: View {
    @State private var feedbackType: FeedbackType = .generalFeedback
    @State private var feedbackText = ""
    @State private var stepsToReproduce = ""
    @State private var attachLogs = true
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) { 
            // Header Section
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Help & Feedback")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Got questions or suggestions? Let us know!")
                        .font(.body)
                }
            }
            Divider()
            
            // Type Selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Feedback Type")
                    .font(.headline)
                    .foregroundColor(ThemeColors.secondaryText)
                
                Picker("", selection: $feedbackType) {
                    ForEach(FeedbackType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }
            
            // Description
            VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                    .font(.headline)
                    .foregroundColor(ThemeColors.secondaryText)
                
                descriptionHelperText()
                    .font(.subheadline)
                    .foregroundColor(ThemeColors.secondaryText)
                    .padding(.bottom, 4)
                
                ZStack(alignment: .bottomTrailing) {
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $feedbackText)
                            .font(.system(.body))
                            .frame(height: 180)
                            .padding(8)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                        
                        if feedbackText.isEmpty {
                            Text(descriptionPlaceholder())
                                .foregroundColor(ThemeColors.secondaryText.opacity(0.5))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    }
                    
                    Text("\(feedbackText.count)/50")
                        .font(.caption)
                        .foregroundColor(feedbackText.count < 50 ? .red.opacity(0.7) : ThemeColors.secondaryText)
                        .padding(12)
                }
            }
            
            // Steps to Reproduce (Only for Bug Report)
            if feedbackType == .bugReport {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Steps to Reproduce")
                        .font(.headline)
                        .foregroundColor(ThemeColors.secondaryText)
                    
                    ZStack(alignment: .bottomTrailing) {
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $stepsToReproduce)
                                .font(.system(.body))
                                .frame(height: 100)
                                .padding(8)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                )
                            
                            if stepsToReproduce.isEmpty {
                                Text("Please list the steps to reproduce the issue")
                                    .foregroundColor(ThemeColors.secondaryText.opacity(0.5))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 16)
                                    .allowsHitTesting(false)
                            }
                        }
                        
                        Text("\(stepsToReproduce.count)/20")
                            .font(.caption)
                            .foregroundColor(stepsToReproduce.count < 20 ? .red.opacity(0.7) : ThemeColors.secondaryText)
                            .padding(12)
                    }
                }
            }
            
            // Attach Logs Checkbox
            Toggle(isOn: $attachLogs) {
                Text("Attach No-Typing app logs")
                    .foregroundColor(.white)
            }
            .toggleStyle(.checkbox)
            .padding(.top, 8)
            
            HStack {
                Spacer()
                Button(action: sendFeedback) {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text("Send Feedback")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(!isFormValid())
            }
        }
        .padding(.top, 16)
        .background(Color.clear)
    }
    
    private func isFormValid() -> Bool {
        if feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).count < 50 {
            return false
        }
        if feedbackType == .bugReport && stepsToReproduce.trimmingCharacters(in: .whitespacesAndNewlines).count < 20 {
            return false
        }
        return true
    }
    
    @ViewBuilder
    private func descriptionHelperText() -> some View {
        switch feedbackType {
        case .bugReport:
            VStack(alignment: .leading, spacing: 4) {
                Text("Please describe the issue in detail. The more actionable your feedback, the quicker our team can address your request. Some helpful information includes:")
                HStack(alignment: .top, spacing: 4) { Text("•"); Text("Steps to reproduce the issue") }
                HStack(alignment: .top, spacing: 4) { Text("•"); Text("Expected behavior") }
                HStack(alignment: .top, spacing: 4) { Text("•"); Text("Actual behavior") }
                HStack(alignment: .top, spacing: 4) { Text("•"); Text("Any error messages") }
                HStack(alignment: .top, spacing: 4) { Text("•"); Text("Any relevant information") }
            }
        case .featureRequest:
            VStack(alignment: .leading, spacing: 4) {
                Text("Please describe the feature you'd like to see. The more detailed the requirements, the easier it will be for our team to incorporate your ideas. Some helpful information includes:")
                HStack(alignment: .top, spacing: 4) { Text("•"); Text("What is missing in your workflow") }
                HStack(alignment: .top, spacing: 4) { Text("•"); Text("What you would like to see to address this gap in your workflow") }
                HStack(alignment: .top, spacing: 4) { Text("•"); Text("How this feature would help you and other users") }
            }
        case .generalFeedback:
            Text("For any feedback that does not fit into the above categories.")
        }
    }
    
    private func descriptionPlaceholder() -> String {
        switch feedbackType {
        case .bugReport: return "Describe the bug you encountered..."
        case .featureRequest: return "Describe the feature you would like to see..."
        case .generalFeedback: return "Enter your feedback here..."
        }
    }
    
    private func sendFeedback() {
        var body = "Type: \(feedbackType.rawValue)\n\n"
        body += "Description:\n\(feedbackText)\n\n"
        if feedbackType == .bugReport {
            body += "Steps to Reproduce:\n\(stepsToReproduce)\n\n"
        }
        body += "Attach Logs: \(attachLogs ? "Yes" : "No")"
        
        if let emailURL = URL(string: "mailto:liam@no_typing.ai?subject=No-Typing%20Feedback&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            NSWorkspace.shared.open(emailURL)
        }
    }
}

// Keeping HoverButtonStyle for compatibility if it's used elsewhere, although no longer strictly required by SupportView currently.
struct HoverButtonStyle: ButtonStyle {
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(isHovered ? Color.blue.opacity(0.1) : Color.secondary.opacity(0.1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue.opacity(isHovered ? 0.3 : 0.2), lineWidth: isHovered ? 1.5 : 1)
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}