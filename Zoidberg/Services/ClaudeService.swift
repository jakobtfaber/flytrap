// Zoidberg/Services/ClaudeService.swift
import Foundation

final class ClaudeService {
    let apiKey: String?
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let model = "claude-haiku-4-5-20251001"
    private let timeout: TimeInterval = 30

    var isEnabled: Bool { apiKey != nil && !(apiKey?.isEmpty ?? true) }

    init(apiKey: String?) {
        self.apiKey = apiKey
    }

    func cleanup(text: String) async -> String? {
        guard isEnabled, let apiKey = apiKey else { return nil }

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "messages": [
                ["role": "user", "content": "Format this into clean notes. Fix punctuation, spacing, and structure. Don't change meaning. Reply with ONLY the formatted text, nothing else.\n\n\(text)"]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = json["content"] as? [[String: Any]],
                  let firstBlock = content.first,
                  let result = firstBlock["text"] as? String else { return nil }
            return result
        } catch {
            return nil
        }
    }
}
