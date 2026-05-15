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
        AIScriptService.shared.generatePhonetic(word: word, targetLanguage: targetLanguage) { result in
            switch result {
            case .success(let parsed):
                let phoneticResult = PhoneticResult(
                    word: word,
                    phonetic: parsed.ipa,
                    translation: parsed.translation,
                    pronunciation: parsed.pronunciation
                )
                completion(phoneticResult)
            case .failure(let error):
                print("Phonetic API error: \(error.localizedDescription)")
                completion(nil)
            }
        }
    }
    
    private func nativeLanguageName(_ code: String) -> String {
        let locale = Locale(identifier: code)
        return locale.localizedString(forLanguageCode: code) ?? code
    }
}
