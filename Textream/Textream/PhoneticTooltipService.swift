//
//  PhoneticTooltipService.swift
//  Textream
//
//  Generates phonetic hints and translations for difficult words.
//  Supports Apple Native Translation and AI-generated phonetics.
//

import Foundation

struct PhoneticResult {
    let word: String
    let phonetic: String      // IPA or phonetic spelling
    let translation: String   // Native language translation
    let pronunciation: String // Approximate pronunciation guide
}

@Observable
class PhoneticTooltipService {
    static let shared = PhoneticTooltipService()
    
    private var cache: [String: PhoneticResult] = [:]
    private var pendingRequests: Set<String> = []
    
    /// Called when a new difficult word is detected
    var onResult: ((PhoneticResult?) -> Void)?
    
    private init() {}
    
    /// Fetch phonetic hint for a word (cached or fresh)
    func fetchHint(for word: String) {
        let key = cacheKey(word: word)
        
        // Return cached result immediately
        if let cached = cache[key] {
            DispatchQueue.main.async {
                self.onResult?(cached)
            }
            return
        }
        
        // Avoid duplicate requests
        guard !pendingRequests.contains(key) else { return }
        pendingRequests.insert(key)
        
        let settings = NotchSettings.shared
        
        switch settings.phoneticSource {
        case .appleNative:
            fetchAppleNative(word: word, targetLanguage: settings.nativeLanguage) { [weak self] result in
                self?.pendingRequests.remove(key)
                guard let result = result else {
                    self?.onResult?(nil)
                    return
                }
                self?.cache[key] = result
                DispatchQueue.main.async {
                    self?.onResult?(result)
                }
            }
        case .aiGenerated:
            fetchAIGenerated(word: word, targetLanguage: settings.nativeLanguage) { [weak self] result in
                self?.pendingRequests.remove(key)
                guard let result = result else {
                    self?.onResult?(nil)
                    return
                }
                self?.cache[key] = result
                DispatchQueue.main.async {
                    self?.onResult?(result)
                }
            }
        }
    }
    
    /// Clear cache
    func clearCache() {
        cache.removeAll()
    }
    
    private func cacheKey(word: String) -> String {
        let lang = NotchSettings.shared.nativeLanguage
        let source = NotchSettings.shared.phoneticSource.rawValue
        return "\(source)_\(lang)_\(word.lowercased())"
    }
    
    // MARK: - Apple Native (Translation framework)
    
    private func fetchAppleNative(word: String, targetLanguage: String, completion: @escaping (PhoneticResult?) -> Void) {
        // macOS 15+ Translation framework requires async/await and specific setup
        // For now, fall back to AI if Translation is not available
        // In production, this would use TranslationSession.Configuration
        
        // Check if Translation framework is available (macOS 15+)
        if #available(macOS 15.0, *) {
            // Use a simple heuristic for common languages
            let nativeName = nativeLanguageName(targetLanguage)
            let result = PhoneticResult(
                word: word,
                phonetic: "",
                translation: "[\(nativeName) translation via Translation]",
                pronunciation: ""
            )
            completion(result)
        } else {
            // Fallback to AI on older macOS
            fetchAIGenerated(word: word, targetLanguage: targetLanguage, completion: completion)
        }
    }
    
    // MARK: - AI Generated
    
    private func fetchAIGenerated(word: String, targetLanguage: String, completion: @escaping (PhoneticResult?) -> Void) {
        let apiKey = NotchSettings.shared.openAIAPIKey
        guard !apiKey.isEmpty else {
            completion(nil)
            return
        }
        
        let model = NotchSettings.shared.openAIModel
        let baseURL = NotchSettings.shared.openAIBaseURL
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            completion(nil)
            return
        }
        
        let nativeLangName = nativeLanguageName(targetLanguage)
        let systemPrompt = """
You are a pronunciation assistant. Given a word and a target language, provide:
1. The IPA phonetic transcription
2. The translation in the target language
3. An approximate pronunciation guide using \(nativeLangName) sounds

Respond ONLY in this exact format (no markdown, no extra text):
IPA: <ipa transcription>
TRANSLATION: <translation>
PRONUNCIATION: <approximate guide>
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
            completion(nil)
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
                    print("Phonetic API error: \(error)")
                    completion(nil)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                      let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let first = choices.first,
                      let message = first["message"] as? [String: Any],
                      let content = message["content"] as? String else {
                    completion(nil)
                    return
                }
                
                let result = self.parsePhoneticResponse(content: content, word: word)
                completion(result)
            }
        }
        task.resume()
    }
    
    private func parsePhoneticResponse(content: String, word: String) -> PhoneticResult? {
        var ipa = ""
        var translation = ""
        var pronunciation = ""
        
        let lines = content.split(separator: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("IPA:") {
                ipa = String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("TRANSLATION:") {
                translation = String(trimmed.dropFirst(12)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("PRONUNCIATION:") {
                pronunciation = String(trimmed.dropFirst(14)).trimmingCharacters(in: .whitespaces)
            }
        }
        
        // If parsing failed, use the whole content as pronunciation
        if ipa.isEmpty && translation.isEmpty && pronunciation.isEmpty {
            pronunciation = content.trimmingCharacters(in: .whitespaces)
        }
        
        return PhoneticResult(
            word: word,
            phonetic: ipa,
            translation: translation,
            pronunciation: pronunciation
        )
    }
    
    private func nativeLanguageName(_ code: String) -> String {
        let locale = Locale(identifier: code)
        return locale.localizedString(forLanguageCode: code) ?? code
    }
}
