import SwiftUI

struct WebhookSettingsView: View {
    @StateObject private var webhookManager = WebhookManager.shared
    @State private var selectedTab: Int = 0
    
    // Add form state
    @State private var newName: String = ""
    @State private var newURL: String = ""
    @State private var newHeaders: [(key: String, value: String)] = []
    @State private var headerKey: String = ""
    @State private var headerValue: String = ""
    @State private var showingHeadersEditor: Bool = false
    
    // Test state per endpoint
    @State private var testingEndpointId: UUID?
    @State private var testResults: [UUID: (success: Bool, message: String)] = [:]
    
    private var samplePayloadString: String {
        """
        {
          "text": "Your transcribed text here...",
          "timestamp": "\(ISO8601DateFormatter().string(from: Date()))",
          "source": "Notes App"
        }
        """
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
                  HStack(spacing: 10) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Please note that adding webhooks would not automatically forward transcriptions. You would need to enable forwarding of transcriptions under App Settings.")
                                        .font(.system(size: 11))
                                        .foregroundColor(.orange.opacity(0.8))
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.orange.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.orange.opacity(0.25), lineWidth: 1)
                            )
                            .cornerRadius(10)
          
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
                    
                    Button(action: { showingHeadersEditor.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "list.bullet.indent")
                            if !newHeaders.isEmpty {
                                Text("\(newHeaders.count)")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 4)
                                    .background(ThemeColors.accent)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("Manage Headers")
            }
                
                HStack(spacing: 8) {
                    if showingHeadersEditor {
                        headersEditor
                            .padding(10)
                            .background(Color.black.opacity(0.2))
                            .cornerRadius(8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                Button(action: {
                    guard !newName.isEmpty, !newURL.isEmpty, newURL.lowercased().hasPrefix("http") else { return }
                    
                    var headersDict: [String: String] = [:]
                    for pair in newHeaders {
                        if !pair.key.isEmpty {
                            headersDict[pair.key] = pair.value
                        }
                    }
                    
                    webhookManager.addEndpoint(name: newName, url: newURL, headers: headersDict)
                    newName = ""
                    newURL = ""
                    newHeaders = []
                }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Save")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(newName.isEmpty || newURL.isEmpty ? .gray : .white)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8) }
                .buttonStyle(.plain)
                .disabled(newName.isEmpty || newURL.isEmpty || !newURL.lowercased().hasPrefix("http"))
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
                
                if !endpoint.headers.isEmpty {
                    Text("\(endpoint.headers.count) header\(endpoint.headers.count == 1 ? "" : "s")")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(ThemeColors.accent.opacity(0.8))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(ThemeColors.accent.opacity(0.1))
                        .cornerRadius(3)
                }
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
    
    // MARK: - Headers Editor View
    
    private var headersEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Custom HTTP Headers")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white.opacity(0.7))
            
            // Current Headers
            if !newHeaders.isEmpty {
                VStack(spacing: 4) {
                    ForEach(0..<newHeaders.count, id: \.self) { index in
                        HStack {
                            Text(newHeaders[index].key)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.white.opacity(0.9))
                            Text(":")
                                .foregroundColor(.white.opacity(0.4))
                            Text(newHeaders[index].value)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(ThemeColors.secondaryText)
                            Spacer()
                            Button(action: { newHeaders.remove(at: index) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(4)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(4)
                    }
                }
            }
            
            // Add New Header Row
            HStack(spacing: 8) {
                TextField("Key", text: $headerKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 11, design: .monospaced))
                
                TextField("Value", text: $headerValue)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 11, design: .monospaced))
                
                Button(action: {
                    guard !headerKey.isEmpty else { return }
                    newHeaders.append((key: headerKey, value: headerValue))
                    headerKey = ""
                    headerValue = ""
                }) {
                    Image(systemName: "plus.circle")
                        .foregroundColor(headerKey.isEmpty ? .gray : .green)
                }
                .buttonStyle(.plain)
                .disabled(headerKey.isEmpty)
            }
            
            Text("Common headers: Authorization, X-API-Key, etc.")
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.4))
        }
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
