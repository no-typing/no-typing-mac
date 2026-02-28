import Foundation

// MARK: - Models

struct WebhookEndpoint: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var url: String
    let createdAt: Date
    
    init(name: String, url: String) {
        self.id = UUID()
        self.name = name
        self.url = url
        self.createdAt = Date()
    }
}

struct WebhookCallRecord: Codable, Identifiable {
    let id: UUID
    let endpointName: String
    let url: String
    let timestamp: Date
    let statusCode: Int?
    let success: Bool
    let errorMessage: String?
    let payloadPreview: String
    
    init(endpointName: String, url: String, statusCode: Int?, success: Bool, errorMessage: String?, payloadPreview: String) {
        self.id = UUID()
        self.endpointName = endpointName
        self.url = url
        self.timestamp = Date()
        self.statusCode = statusCode
        self.success = success
        self.errorMessage = errorMessage
        self.payloadPreview = payloadPreview
    }
}

// MARK: - Manager

class WebhookManager: ObservableObject {
    static let shared = WebhookManager()
    
    @Published var endpoints: [WebhookEndpoint] = []
    @Published var callHistory: [WebhookCallRecord] = []
    
    private let endpointsKey = "webhookEndpoints"
    private let historyKey = "webhookCallHistory"
    private let maxHistoryRecords = 200
    
    private init() {
        loadEndpoints()
        loadHistory()
        migrateIfNeeded()
    }
    
    // MARK: - Migration from single-endpoint system
    
    private func migrateIfNeeded() {
        let defaults = UserDefaults.standard
        if let legacyURL = defaults.string(forKey: "webhookURL"), !legacyURL.isEmpty {
            let endpoint = WebhookEndpoint(name: "Default Webhook", url: legacyURL)
            endpoints.append(endpoint)
            saveEndpoints()
            
            // If it was the active webhook, set it as voice webhook
            if defaults.bool(forKey: "webhookEnabled") {
                defaults.set(endpoint.id.uuidString, forKey: "voiceWebhookEndpointId")
            }
            
            // Remove legacy keys
            defaults.removeObject(forKey: "webhookURL")
            defaults.removeObject(forKey: "webhookEnabled")
        }
    }
    
    // MARK: - Endpoints CRUD
    
    func addEndpoint(name: String, url: String) {
        let endpoint = WebhookEndpoint(name: name, url: url)
        endpoints.append(endpoint)
        saveEndpoints()
    }
    
    func deleteEndpoint(id: UUID) {
        endpoints.removeAll { $0.id == id }
        saveEndpoints()
        
        // Clear selections that reference this endpoint
        let defaults = UserDefaults.standard
        if defaults.string(forKey: "voiceWebhookEndpointId") == id.uuidString {
            defaults.removeObject(forKey: "voiceWebhookEndpointId")
        }
        if defaults.string(forKey: "fileTranscriptionWebhookEndpointId") == id.uuidString {
            defaults.removeObject(forKey: "fileTranscriptionWebhookEndpointId")
        }
    }
    
    func endpoint(for id: UUID?) -> WebhookEndpoint? {
        guard let id = id else { return nil }
        return endpoints.first { $0.id == id }
    }
    
    // MARK: - Send Transcript
    
    func sendTranscript(text: String, duration: TimeInterval?, endpointId: UUID?) {
        guard let endpointId = endpointId,
              let endpoint = endpoint(for: endpointId),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let url = URL(string: endpoint.url) else {
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let parameters: [String: Any] = [
            "text": text,
            "duration": duration ?? 0,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "source": "No-Typing"
        ]
        
        let preview = String(text.prefix(80))
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: parameters) else {
            return
        }
        
        request.httpBody = httpBody
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode
            let success = statusCode != nil && (200...299).contains(statusCode!)
            
            let record = WebhookCallRecord(
                endpointName: endpoint.name,
                url: endpoint.url,
                statusCode: statusCode,
                success: error == nil && success,
                errorMessage: error?.localizedDescription,
                payloadPreview: preview
            )
            
            DispatchQueue.main.async {
                self?.addHistoryRecord(record)
            }
            
            if let error = error {
                print("⚠️ WebhookManager: Failed to send transcript to \(endpoint.name) - \(error.localizedDescription)")
            } else {
                print("🌐 WebhookManager: Payload sent to \(endpoint.name) (Status \(statusCode ?? 0))")
            }
        }
        task.resume()
    }
    
    // MARK: - Test Webhook
    
    func testWebhook(endpoint: WebhookEndpoint) async throws -> Bool {
        guard let url = URL(string: endpoint.url) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let parameters: [String: Any] = [
            "text": "Hello from No-Typing! This is a test webhook payload to verify connectivity.",
            "duration": 5.0,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "source": "No-Typing"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        let httpResponse = response as? HTTPURLResponse
        let statusCode = httpResponse?.statusCode
        let success = statusCode != nil && (200...299).contains(statusCode!)
        
        let record = WebhookCallRecord(
            endpointName: endpoint.name,
            url: endpoint.url,
            statusCode: statusCode,
            success: success,
            errorMessage: success ? nil : "HTTP \(statusCode ?? 0)",
            payloadPreview: "Test payload"
        )
        
        await MainActor.run {
            addHistoryRecord(record)
        }
        
        guard success else {
            throw URLError(.badServerResponse)
        }
        
        return true
    }
    
    // MARK: - History
    
    private func addHistoryRecord(_ record: WebhookCallRecord) {
        callHistory.insert(record, at: 0)
        if callHistory.count > maxHistoryRecords {
            callHistory = Array(callHistory.prefix(maxHistoryRecords))
        }
        saveHistory()
    }
    
    func clearHistory() {
        callHistory.removeAll()
        saveHistory()
    }
    
    // MARK: - Persistence
    
    private func loadEndpoints() {
        guard let data = UserDefaults.standard.data(forKey: endpointsKey),
              let decoded = try? JSONDecoder().decode([WebhookEndpoint].self, from: data) else {
            return
        }
        endpoints = decoded
    }
    
    private func saveEndpoints() {
        guard let data = try? JSONEncoder().encode(endpoints) else { return }
        UserDefaults.standard.set(data, forKey: endpointsKey)
    }
    
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let decoded = try? JSONDecoder().decode([WebhookCallRecord].self, from: data) else {
            return
        }
        callHistory = decoded
    }
    
    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(callHistory) else { return }
        UserDefaults.standard.set(data, forKey: historyKey)
    }
}
