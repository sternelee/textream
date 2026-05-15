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
    case requestInProgress
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
        case .requestInProgress:
            return "Another AI generation is already in progress. Stop it before starting a new one."
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
    private var activeRequestID: UUID?
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
        activeRequestID = nil
        currentTask?.cancel()
        currentTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        isGenerating = false
    }

    /// Generate a script based on scenario and user prompt
    func generate(
        scenario: AIScenario,
        userPrompt: String,
        onUpdate: @escaping (String) -> Void,
        onComplete: @escaping (Result<String, AIScriptError>) -> Void
    ) {
        let fullUserPrompt = """
Scenario: \(scenario.label)
\(userPrompt)

Generate a complete script suitable for reading on a teleprompter. Keep it natural and conversational.
"""
        performStreamedRequest(
            scenario: scenario,
            userPrompt: fullUserPrompt,
            onUpdate: onUpdate,
            onComplete: onComplete
        )
    }

    /// Continue generating from existing text
    func continueFrom(
        existingText: String,
        scenario: AIScenario,
        userPrompt: String,
        onUpdate: @escaping (String) -> Void,
        onComplete: @escaping (Result<String, AIScriptError>) -> Void
    ) {
        let fullUserPrompt = """
Continue the following script from where it left off. Maintain the same tone, style, and format.
Match the voice and pacing of the existing text. Add natural transitions.

Existing script:
---
\(existingText)
---

Continue the script. The user also provided: \(userPrompt)
"""
        performStreamedRequest(
            scenario: scenario,
            userPrompt: fullUserPrompt,
            onUpdate: onUpdate,
            onComplete: onComplete
        )
    }

    // MARK: - Shared Streaming Request

    private func performStreamedRequest(
        scenario: AIScenario,
        userPrompt: String,
        onUpdate: @escaping (String) -> Void,
        onComplete: @escaping (Result<String, AIScriptError>) -> Void
    ) {
        guard activeRequestID == nil, currentTask == nil, !isGenerating else {
            onComplete(.failure(.requestInProgress))
            return
        }

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
        let requestID = UUID()
        activeRequestID = requestID

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": scenario.systemPrompt],
                ["role": "user", "content": userPrompt]
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
        let delegate = StreamingDelegate(service: self, requestID: requestID, onUpdate: onUpdate, onComplete: onComplete)
        let streamSession = URLSession(configuration: .default, delegate: delegate, delegateQueue: .main)
        self.urlSession = streamSession

        let streamTask = streamSession.dataTask(with: request)
        self.currentTask = streamTask
        streamTask.resume()
    }

    fileprivate func isRequestActive(_ requestID: UUID) -> Bool {
        activeRequestID == requestID
    }

    fileprivate func appendChunk(_ chunk: String, for requestID: UUID) -> String? {
        guard activeRequestID == requestID else { return nil }
        generatedText += chunk
        return generatedText
    }

    fileprivate func finishStreamingRequest(_ requestID: UUID) -> String? {
        guard activeRequestID == requestID else { return nil }
        let finalText = generatedText
        activeRequestID = nil
        currentTask = nil
        urlSession = nil
        isGenerating = false
        return finalText
    }

    fileprivate func failStreamingRequest(_ requestID: UUID) -> Bool {
        guard activeRequestID == requestID else { return false }
        activeRequestID = nil
        currentTask = nil
        urlSession = nil
        isGenerating = false
        return true
    }

    fileprivate func completeStreamingRequest(_ requestID: UUID) {
        guard activeRequestID == requestID else { return }
        activeRequestID = nil
        currentTask = nil
        urlSession = nil
        isGenerating = false
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
                    let message = Self.extractErrorMessage(from: data, statusCode: httpResponse.statusCode)
                    onComplete(.failure(.apiError(message)))
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

    /// Polish selected text with a specific instruction
    func polish(
        text: String,
        instruction: String,
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

        let systemPrompt = """
You are an expert script editor. Rewrite the provided text according to the user's instruction.
Preserve the original structure including [pause], [emphasis], and other markup tags.
Only return the rewritten text, no explanations.
"""
        let userPrompt = "Instruction: \(instruction)\n\nText:\n---\n\(text)\n---"

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "stream": false,
            "temperature": 0.7,
            "max_tokens": 2048
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
                    let message = Self.extractErrorMessage(from: data, statusCode: httpResponse.statusCode)
                    onComplete(.failure(.apiError(message)))
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

    /// Generate mock Q&A questions based on script content
    func generateQuestions(
        scriptText: String,
        count: Int = 5,
        onComplete: @escaping (Result<[String], AIScriptError>) -> Void
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

        let systemPrompt = """
You are an expert interviewer. Based on the provided script or speech, generate likely follow-up questions an audience might ask.
The questions should be specific to the content, insightful, and challenging.
Return ONLY a numbered list of questions, one per line. No extra commentary.
"""
        let userPrompt = """
Generate \(count) likely questions that an audience would ask after hearing this speech:

---
\(scriptText)
---

Questions:
"""

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "stream": false,
            "temperature": 0.8,
            "max_tokens": 2048
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
                    let message = Self.extractErrorMessage(from: data, statusCode: httpResponse.statusCode)
                    onComplete(.failure(.apiError(message)))
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
                let questions = content
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty && $0.first?.isNumber == true }
                    .map { line -> String in
                        // Remove leading number and punctuation like "1. " or "1) "
                        let pattern = "^\\d+[.\\)\\-\\s]+"
                        return line.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
                    }
                    .filter { !$0.isEmpty }
                onComplete(.success(questions))
            }
        }
        task.resume()
    }

    // MARK: - Phonetic Generation

    /// Generate phonetic hint for a difficult word (IPA + translation + pronunciation guide)
    func generatePhonetic(
        word: String,
        targetLanguage: String,
        onComplete: @escaping (Result<(ipa: String, ukIPA: String, translation: String, pronunciation: String), AIScriptError>) -> Void
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

        let nativeLangName = Locale(identifier: targetLanguage).localizedString(forLanguageCode: targetLanguage) ?? targetLanguage

        let systemPrompt = """
You are a pronunciation and translation assistant. Given an English word and a target language, provide:
1. American English IPA phonetic transcription
2. British English IPA phonetic transcription (if different from American)
3. The translation in the target language
4. An approximate pronunciation guide using native language sounds

Respond ONLY in this exact format (no markdown, no extra text):
US: <American IPA>
UK: <British IPA>
TRANSLATION: <translation in target language>
PRONUNCIATION: <approximate guide using native sounds>
"""
        let userPrompt = "Word: \"\(word)\"\nTarget language: \(nativeLangName) (\(targetLanguage))"

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "stream": false,
            "temperature": 0.3,
            "max_tokens": 256
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
                    let message = Self.extractErrorMessage(from: data, statusCode: httpResponse.statusCode)
                    onComplete(.failure(.apiError(message)))
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
                let parsed = Self.parsePhoneticResponse(content)
                onComplete(.success(parsed))
            }
        }
        task.resume()
    }

    /// Parse phonetic generation response into structured fields
    /// Handles both old format (IPA:) and new format (US:/UK:)
    static func parsePhoneticResponse(_ content: String) -> (ipa: String, ukIPA: String, translation: String, pronunciation: String) {
        var usIPA = ""
        var ukIPA = ""
        var ipa = ""
        var translation = ""
        var pronunciation = ""

        let lines = content.split(separator: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("US:") {
                usIPA = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("UK:") {
                ukIPA = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("IPA:") {
                ipa = String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("TRANSLATION:") {
                translation = String(trimmed.dropFirst(12)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("PRONUNCIATION:") {
                pronunciation = String(trimmed.dropFirst(14)).trimmingCharacters(in: .whitespaces)
            }
        }

        if !usIPA.isEmpty { ipa = usIPA }

        if ipa.isEmpty && translation.isEmpty && pronunciation.isEmpty {
            pronunciation = content.trimmingCharacters(in: .whitespaces)
        }

        return (ipa: ipa, ukIPA: ukIPA, translation: translation, pronunciation: pronunciation)
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
                    let message = Self.extractErrorMessage(from: data, statusCode: httpResponse.statusCode)
                    completion(.failure(.apiError(message)))
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

    // MARK: - Error Message Extraction

    fileprivate static func extractErrorMessage(from data: Data?, statusCode: Int) -> String {
        guard let data = data else {
            return "HTTP \(statusCode)"
        }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let err = json["error"] as? [String: Any],
           let message = err["message"] as? String {
            return message
        }
        if let rawString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !rawString.isEmpty {
            let maxLength = 200
            let truncated = rawString.count > maxLength ? String(rawString.prefix(maxLength)) + "..." : rawString
            return "HTTP \(statusCode): \(truncated)"
        }
        return "HTTP \(statusCode)"
    }
}

// MARK: - Streaming Delegate

private class StreamingDelegate: NSObject, URLSessionDataDelegate {
    weak var service: AIScriptService?
    let requestID: UUID
    let onUpdate: (String) -> Void
    let onComplete: ((Result<String, AIScriptError>) -> Void)?
    private var buffer = Data()
    private var responseBuffer = Data()
    private var receivedData = false
    private var didCallCompletion = false

    init(service: AIScriptService, requestID: UUID, onUpdate: @escaping (String) -> Void, onComplete: ((Result<String, AIScriptError>) -> Void)? = nil) {
        self.service = service
        self.requestID = requestID
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
        responseBuffer.append(data)
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
                    guard let text = self.service?.finishStreamingRequest(self.requestID) else { return }
                    if !text.isEmpty {
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
                    guard let text = self.service?.appendChunk(content, for: self.requestID) else { return }
                    self.onUpdate(text)
                }
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        defer { session.invalidateAndCancel() }
        DispatchQueue.main.async {
            guard let service = self.service else { return }
            guard service.isRequestActive(self.requestID) else { return }

            if let error = error as NSError? {
                if error.code == NSURLErrorCancelled {
                    let partialText = service.finishStreamingRequest(self.requestID) ?? ""
                    self.callCompletionOnce(.success(partialText))
                    return
                }
                _ = service.failStreamingRequest(self.requestID)
                self.callCompletionOnce(.failure(.networkError(error)))
                return
            }

            if let text = service.finishStreamingRequest(self.requestID), !text.isEmpty {
                self.callCompletionOnce(.success(text))
            } else if !self.receivedData {
                service.completeStreamingRequest(self.requestID)
                self.callCompletionOnce(.failure(.noContent))
            }
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode != 200 {
                DispatchQueue.main.async {
                    guard let service = self.service else { return }
                    let message = AIScriptService.extractErrorMessage(from: self.responseBuffer, statusCode: httpResponse.statusCode)
                    guard service.failStreamingRequest(self.requestID) else { return }
                    self.callCompletionOnce(.failure(.apiError(message)))
                }
                session.invalidateAndCancel()
                completionHandler(.cancel)
                return
            }
        }
        completionHandler(.allow)
    }

}
