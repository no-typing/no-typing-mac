import SwiftUI

struct WebhookSettingsView: View {
    @StateObject private var webhookManager = WebhookManager.shared
    @State private var selectedTab: Int = 0
    
    // Add form state
    @State private var newName: String = ""
    @State private var newURL: String = ""
    
    // Test state per endpoint
    @State private var testingEndpointId: UUID?
    @State private var testResults: [UUID: (success: Bool, message: String)] = [:]
    
    private var samplePayloadString: String {
        """
        {
          "text": "Your transcribed text here...",
          "duration": 12.5,
          "timestamp": "\(ISO8601DateFormatter().string(from: Date()))",
          "source": "No-Typing"
        }
        """
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Integrations & Webhooks")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Forward completed transcripts as JSON payloads to Zapier, Make.com, n8n, Notion or any custom endpoint.")
                    .font(.subheadline)
                    .foregroundColor(ThemeColors.secondaryText)
            }
            
            // Tab Toggle
            HStack(spacing: 0) {
                Button(action: { withAnimation { selectedTab = 0 } }) {
                    Text("Endpoints")
                        .font(.system(size: 13, weight: selectedTab == 0 ? .semibold : .medium))
                        .foregroundColor(selectedTab == 0 ? .white : .white.opacity(0.6))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 16)
                        .background(selectedTab == 0 ? ThemeColors.accent : Color.clear)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                
                Button(action: { withAnimation { selectedTab = 1 } }) {
                    HStack(spacing: 4) {
                        Text("History")
                            .font(.system(size: 13, weight: selectedTab == 1 ? .semibold : .medium))
                            .foregroundColor(selectedTab == 1 ? .white : .white.opacity(0.6))
                        if !webhookManager.callHistory.isEmpty {
                            Text("\(webhookManager.callHistory.count)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.gray.opacity(0.5))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 16)
                    .background(selectedTab == 1 ? ThemeColors.accent : Color.clear)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(4)
            .background(Color.black.opacity(0.3))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.05)))
            
            if selectedTab == 0 {
                endpointsTab
            } else {
                historyTab
            }
        }
        .padding(20)
    }
    
    // MARK: - Endpoints Tab
    
    private var endpointsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Endpoint List
            if webhookManager.endpoints.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 24))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("No webhooks configured")
                        .font(.system(size: 13))
                        .foregroundColor(ThemeColors.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(webhookManager.endpoints) { endpoint in
                    endpointRow(endpoint)
                }
            }
            
            Divider().opacity(0.3)
            
            // Add Webhook Form
            VStack(alignment: .leading, spacing: 8) {
                Text("Add Webhook")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                
                HStack(spacing: 8) {
                    TextField("Name (e.g. Zapier)", text: $newName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 150)
                    
                    TextField("https://hooks.zapier.com/...", text: $newURL)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button(action: {
                        guard !newName.isEmpty, !newURL.isEmpty, newURL.lowercased().hasPrefix("http") else { return }
                        webhookManager.addEndpoint(name: newName, url: newURL)
                        newName = ""
                        newURL = ""
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(newName.isEmpty || newURL.isEmpty ? .gray : ThemeColors.accent)
                    }
                    .buttonStyle(.plain)
                    .disabled(newName.isEmpty || newURL.isEmpty || !newURL.lowercased().hasPrefix("http"))
                }
            }
            
            Divider().opacity(0.3)
            
            // Sample Payload
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Sample Payload")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(samplePayloadString, forType: .string)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 10))
                            Text("Copy")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
                
                Text(samplePayloadString)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.green.opacity(0.8))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.05)))
                    .textSelection(.enabled)
            }
        }
    }
    
    // MARK: - Endpoint Row
    
    private func endpointRow(_ endpoint: WebhookEndpoint) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(endpoint.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text(endpoint.url)
                    .font(.system(size: 11))
                    .foregroundColor(ThemeColors.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            // Test result badge
            if let result = testResults[endpoint.id] {
                HStack(spacing: 4) {
                    Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 12))
                    Text(result.message)
                        .font(.system(size: 10))
                }
                .foregroundColor(result.success ? .green : .red)
            }
            
            // Test button
            Button(action: { testEndpoint(endpoint) }) {
                if testingEndpointId == endpoint.id {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .buttonStyle(.plain)
            .disabled(testingEndpointId != nil)
            .help("Send test payload")
            
            // Delete button
            Button(action: { webhookManager.deleteEndpoint(id: endpoint.id) }) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help("Delete webhook")
        }
        .padding(10)
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.05)))
    }
    
    // MARK: - History Tab
    
    private var historyTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            if webhookManager.callHistory.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 24))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("No webhook calls yet")
                        .font(.system(size: 13))
                        .foregroundColor(ThemeColors.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                HStack {
                    Spacer()
                    Button(action: { webhookManager.clearHistory() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                            Text("Clear History")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.red.opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                }
                
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(webhookManager.callHistory) { record in
                            historyRow(record)
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
    }
    
    // MARK: - History Row
    
    private func historyRow(_ record: WebhookCallRecord) -> some View {
        HStack(spacing: 10) {
            // Status icon
            Image(systemName: record.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(record.success ? .green : .red)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(record.endpointName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                    
                    if let code = record.statusCode {
                        Text("\(code)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(record.success ? .green.opacity(0.8) : .red.opacity(0.8))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background((record.success ? Color.green : Color.red).opacity(0.15))
                            .cornerRadius(3)
                    }
                }
                
                Text(record.payloadPreview)
                    .font(.system(size: 10))
                    .foregroundColor(ThemeColors.secondaryText)
                    .lineLimit(1)
                    
                if let error = record.errorMessage {
                    Text(error)
                        .font(.system(size: 10))
                        .foregroundColor(.red.opacity(0.7))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Text(formatTimestamp(record.timestamp))
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(8)
        .background(Color.white.opacity(0.02))
        .cornerRadius(6)
    }
    
    // MARK: - Actions
    
    private func testEndpoint(_ endpoint: WebhookEndpoint) {
        testingEndpointId = endpoint.id
        testResults.removeValue(forKey: endpoint.id)
        
        Task {
            do {
                _ = try await webhookManager.testWebhook(endpoint: endpoint)
                await MainActor.run {
                    testResults[endpoint.id] = (success: true, message: "OK")
                    testingEndpointId = nil
                }
            } catch {
                await MainActor.run {
                    testResults[endpoint.id] = (success: false, message: error.localizedDescription)
                    testingEndpointId = nil
                }
            }
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
