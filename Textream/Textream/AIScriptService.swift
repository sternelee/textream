//
//  AIScriptService.swift
//  Textream
//
//  OpenAI API integration for AI script generation.
//

import Foundation

enum AIScriptError: Error, LocalizedError {
    case missingAPIKey
    case invalidURL
    case networkError(Error)
    case apiError(String)
    case decodingError
    case noContent

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API Key is not configured. Add it in Settings → AI."
        case .invalidURL:
            return "Invalid API URL. Check your settings."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .apiError(let message):
            return "API error: \(message)"
        case .decodingError:
            return "Failed to decode API response."
        case .noContent:
            return "No content was generated. Try again."
        }
    }
}

@Observable
class AIScriptService {
    static let shared = AIScriptService()

    var isGenerating = false
    var generatedText = ""
    var error: String?
    var modelName = ""

    private var urlSession: URLSession?
    fileprivate var currentTask: URLSessionDataTask?

    /// Default models shown before fetching from remote
    static let defaultModels = [
        "gpt-4o",
        "gpt-4o-mini",
        "gpt-4-turbo",
        "gpt-3.5-turbo",
    ]

    /// Fetched models from remote API (persisted in UserDefaults)
    var availableModels: [String] {
        get {
            UserDefaults.standard.stringArray(forKey: "aiAvailableModels") ?? Self.defaultModels
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "aiAvailableModels")
        }
    }

    /// Check if API key is configured
    var hasAPIKey: Bool {
        !NotchSettings.shared.openAIAPIKey.isEmpty
    }

    /// Stop any ongoing generation
    func stop() {
        currentTask?.cancel()
        currentTask = nil
        isGenerating = false
    }

    /// Generate a script based on scenario and user prompt
    func generate(
        scenario: AIScenario,
        userPrompt: String,
        onUpdate: @escaping (String) -> Void,
        onComplete: @escaping (Result<String, AIScriptError>) -> Void
    ) {
        let apiKey = NotchSettings.shared.openAIAPIKey
        guard !apiKey.isEmpty else {
            onComplete(.failure(.missingAPIKey))
            return
        }

        let model = NotchSettings.shared.openAIModel
        let baseURL = NotchSettings.shared.openAIBaseURL

        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            onComplete(.failure(.invalidURL))
            return
        }

        isGenerating = true
        generatedText = ""
        error = nil
        modelName = model

        let systemPrompt = scenario.systemPrompt
        let fullUserPrompt = """
Scenario: \(scenario.label)
\(userPrompt)

Generate a complete script suitable for reading on a teleprompter. Keep it natural and conversational.
"""

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": fullUserPrompt]
            ],
            "stream": true,
            "temperature": 0.8,
            "max_tokens": 4096
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            isGenerating = false
            onComplete(.failure(.decodingError))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData

        // Use URLSession delegate for streaming
        let delegate = StreamingDelegate(service: self, onUpdate: onUpdate, onComplete: onComplete)
        let streamSession = URLSession(configuration: .default, delegate: delegate, delegateQueue: .main)
        self.urlSession = streamSession

        let streamTask = streamSession.dataTask(with: request)
        self.currentTask = streamTask
        streamTask.resume()
    }

    /// Continue generating from existing text
    func continueFrom(
        existingText: String,
        scenario: AIScenario,
        userPrompt: String,
        onUpdate: @escaping (String) -> Void,
        onComplete: @escaping (Result<String, AIScriptError>) -> Void
    ) {
        let apiKey = NotchSettings.shared.openAIAPIKey
        guard !apiKey.isEmpty else {
            onComplete(.failure(.missingAPIKey))
            return
        }

        let model = NotchSettings.shared.openAIModel
        let baseURL = NotchSettings.shared.openAIBaseURL

        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            onComplete(.failure(.invalidURL))
            return
        }

        isGenerating = true
        generatedText = ""
        error = nil
        modelName = model

        let systemPrompt = scenario.systemPrompt
        let fullUserPrompt = """
Continue the following script from where it left off. Maintain the same tone, style, and format.
Match the voice and pacing of the existing text. Add natural transitions.

Existing script:
---
\(existingText)
---

Continue the script. The user also provided: \(userPrompt)
"""

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": fullUserPrompt]
            ],
            "stream": true,
            "temperature": 0.8,
            "max_tokens": 4096
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            isGenerating = false
            onComplete(.failure(.decodingError))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData

        let delegate = StreamingDelegate(service: self, onUpdate: onUpdate, onComplete: onComplete)
        let streamSession = URLSession(configuration: .default, delegate: delegate, delegateQueue: .main)
        self.urlSession = streamSession

        let streamTask = streamSession.dataTask(with: request)
        self.currentTask = streamTask
        streamTask.resume()
    }

    func appendChunk(_ chunk: String) {
        generatedText += chunk
    }

    /// Pre-generate the next page of script while preserving context continuity.
    /// Used by auto-generate feature to seamlessly continue the same scenario/topic.
    func preGenerateNextPage(
        scenario: AIScenario,
        context: String,
        existingText: String,
        onComplete: @escaping (Result<String, AIScriptError>) -> Void
    ) {
        let apiKey = NotchSettings.shared.openAIAPIKey
        guard !apiKey.isEmpty else {
            onComplete(.failure(.missingAPIKey))
            return
        }

        let model = NotchSettings.shared.openAIModel
        let baseURL = NotchSettings.shared.openAIBaseURL

        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            onComplete(.failure(.invalidURL))
            return
        }

        let systemPrompt = scenario.systemPrompt
        let fullUserPrompt = """
Continue the following script with a NEW section/page that follows naturally.
The new section should be a fresh continuation on the same topic, with a smooth transition from the previous text.
Do NOT repeat content from the existing script. Write entirely new material that extends the narrative.

Existing script (already read):
---
\(existingText)
---

Context/Topic: \(context)

Generate the next page of the script. Maintain the same tone, style, and format. Include [pause] and stage directions.
"""

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": fullUserPrompt]
            ],
            "stream": false,
            "temperature": 0.8,
            "max_tokens": 4096
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            onComplete(.failure(.decodingError))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    onComplete(.failure(.networkError(error)))
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    onComplete(.failure(.networkError(NSError(domain: "", code: -1))))
                    return
                }

                if httpResponse.statusCode != 200 {
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let err = json["error"] as? [String: Any],
                       let message = err["message"] as? String {
                        onComplete(.failure(.apiError(message)))
                    } else {
                        onComplete(.failure(.apiError("HTTP \(httpResponse.statusCode)")))
                    }
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let first = choices.first,
                      let message = first["message"] as? [String: Any],
                      let content = message["content"] as? String else {
                    onComplete(.failure(.decodingError))
                    return
                }

                onComplete(.success(content.trimmingCharacters(in: .whitespacesAndNewlines)))
            }
        }
        task.resume()
    }

    /// Fetch available models from the remote API
    func fetchModels(completion: @escaping (Result<[String], AIScriptError>) -> Void) {
        let apiKey = NotchSettings.shared.openAIAPIKey
        guard !apiKey.isEmpty else {
            completion(.failure(.missingAPIKey))
            return
        }

        let baseURL = NotchSettings.shared.openAIBaseURL
        guard let url = URL(string: "\(baseURL)/models") else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(.networkError(error)))
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(.networkError(NSError(domain: "", code: -1))))
                    return
                }

                if httpResponse.statusCode != 200 {
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let err = json["error"] as? [String: Any],
                       let message = err["message"] as? String {
                        completion(.failure(.apiError(message)))
                    } else {
                        completion(.failure(.apiError("HTTP \(httpResponse.statusCode)")))
                    }
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let modelsData = json["data"] as? [[String: Any]] else {
                    completion(.failure(.decodingError))
                    return
                }

                // Filter for chat-completion capable models
                let modelIDs = modelsData
                    .compactMap { $0["id"] as? String }
                    .filter { id in
                        // Exclude embedding, TTS, image, and other non-chat models
                        let excludedPrefixes = [
                            "embedding", "tts", "whisper", "dall-e", "babbage", "davinci",
                            "text-", "audio", "omni-moderation"
                        ]
                        for prefix in excludedPrefixes {
                            if id.lowercased().contains(prefix) { return false }
                        }
                        return true
                    }
                    .sorted()

                self.availableModels = modelIDs.isEmpty ? Self.defaultModels : modelIDs
                completion(.success(self.availableModels))
            }
        }
        task.resume()
    }
}

// MARK: - Streaming Delegate

private class StreamingDelegate: NSObject, URLSessionDataDelegate {
    weak var service: AIScriptService?
    let onUpdate: (String) -> Void
    let onComplete: ((Result<String, AIScriptError>) -> Void)?
    private var buffer = Data()
    private var receivedData = false
    private var didCallCompletion = false

    init(service: AIScriptService, onUpdate: @escaping (String) -> Void, onComplete: ((Result<String, AIScriptError>) -> Void)? = nil) {
        self.service = service
        self.onUpdate = onUpdate
        self.onComplete = onComplete
    }

    private func callCompletionOnce(_ result: Result<String, AIScriptError>) {
        guard !didCallCompletion else { return }
        didCallCompletion = true
        onComplete?(result)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        receivedData = true
        buffer.append(data)

        // Process complete lines
        while let newlineRange = buffer.range(of: Data("\n".utf8)) {
            let line = buffer.prefix(upTo: newlineRange.lowerBound)
            buffer.removeSubrange(..<newlineRange.upperBound)

            let lineString = String(data: line, encoding: .utf8)?.trimmingCharacters(in: .whitespaces)
            guard let lineString = lineString, lineString.hasPrefix("data: ") else { continue }

            let jsonString = String(lineString.dropFirst(6))
            if jsonString == "[DONE]" {
                DispatchQueue.main.async {
                    self.service?.isGenerating = false
                    self.service?.currentTask = nil
                    if let text = self.service?.generatedText, !text.isEmpty {
                        self.callCompletionOnce(.success(text))
                    } else {
                        self.callCompletionOnce(.failure(.noContent))
                    }
                }
                return
            }

            guard let jsonData = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let first = choices.first,
                  let delta = first["delta"] as? [String: Any] else { continue }

            if let content = delta["content"] as? String {
                DispatchQueue.main.async {
                    self.service?.appendChunk(content)
                    self.onUpdate(self.service?.generatedText ?? "")
                }
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DispatchQueue.main.async {
            self.service?.isGenerating = false
            self.service?.currentTask = nil

            if let error = error as NSError? {
                if error.code == NSURLErrorCancelled {
                    self.callCompletionOnce(.success(self.service?.generatedText ?? ""))
                    return
                }
                self.callCompletionOnce(.failure(.networkError(error)))
                return
            }

            if let text = self.service?.generatedText, !text.isEmpty {
                self.callCompletionOnce(.success(text))
            } else if !self.receivedData {
                self.callCompletionOnce(.failure(.noContent))
            }
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode != 200 {
                DispatchQueue.main.async {
                    self.service?.isGenerating = false
                    self.service?.currentTask = nil
                    self.callCompletionOnce(.failure(.apiError("HTTP \(httpResponse.statusCode)")))
                }
                completionHandler(.cancel)
                return
            }
        }
        completionHandler(.allow)
    }
}
