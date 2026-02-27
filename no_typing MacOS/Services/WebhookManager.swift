import Foundation

class WebhookManager {
    static let shared = WebhookManager()
    private init() {}
    
    func sendTranscript(text: String, duration: TimeInterval?) {
        let isEnabled = UserDefaults.standard.bool(forKey: "webhookEnabled")
        let urlString = UserDefaults.standard.string(forKey: "webhookURL") ?? ""
        
        guard isEnabled,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let url = URL(string: urlString) else {
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
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: parameters) else {
            return
        }
        
        request.httpBody = httpBody
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("⚠️ WebhookManager: Failed to send transcript - \(error.localizedDescription)")
            } else if let httpResponse = response as? HTTPURLResponse {
                print("🌐 WebhookManager: Payload sent successfully (Status \(httpResponse.statusCode))")
            }
        }
        task.resume()
    }
    
    // Explicit Test Call for Settings View
    func testWebhook(url urlString: String) async throws -> Bool {
        guard let url = URL(string: urlString) else {
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
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        return true
    }
}
