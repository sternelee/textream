//
//  PhoneticTooltipService.swift
//  Textream
//
//  Generates phonetic hints and translations for difficult words.
//  Supports Apple Native Translation and AI-generated phonetics.
//

import Foundation
import AVFoundation

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
    private var pendingRequests = Set<String>()
    
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
                guard let result = result, let self else {
                    self?.onResult?(nil)
                    return
                }
                self.cache[key] = result
                DispatchQueue.main.async {
                    self.onResult?(result)
                }
            }
        case .aiGenerated:
            fetchAIGenerated(word: word, targetLanguage: settings.nativeLanguage) { [weak self] result in
                self?.pendingRequests.remove(key)
                guard let result = result, let self else {
                    self?.onResult?(nil)
                    return
                }
                self.cache[key] = result
                DispatchQueue.main.async {
                    self.onResult?(result)
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
    
    // MARK: - Apple Native (Translation + local IPA lookup)
    
    private func fetchAppleNative(word: String, targetLanguage: String, completion: @escaping (PhoneticResult?) -> Void) {
        if #available(macOS 15.0, *) {
            translateWithApple(word: word, targetLanguage: targetLanguage, completion: completion)
        } else {
            // Fallback to AI on older macOS
            fetchAIGenerated(word: word, targetLanguage: targetLanguage, completion: completion)
        }
    }
    
    @available(macOS 15.0, *)
    private func translateWithApple(word: String, targetLanguage: String, completion: @escaping (PhoneticResult?) -> Void) {
        // Translation framework requires SwiftUI .translationTask modifier for proper session management.
        // Since PhoneticTooltipService operates outside a SwiftUI view context, we cannot
        // reliably use TranslationSession here. Fall back to AI which provides
        // IPA + translation + pronunciation guide in a single call.
        fetchAIGenerated(word: word, targetLanguage: targetLanguage, completion: completion)
    }
    
    // MARK: - IPA Phonetic Generation (local lookup)
    
    /// Common English word → IPA mapping for immediate results without API calls
    private let commonIPA: [String: String] = [
        "the": "/ðə/", "a": "/ə/", "an": "/ən/", "and": "/ænd/", "or": "/ɔːr/",
        "of": "/ʌv/", "to": "/tuː/", "in": "/ɪn/", "for": "/fɔːr/", "with": "/wɪð/",
        "is": "/ɪz/", "it": "/ɪt/", "that": "/ðæt/", "this": "/ðɪs/", "are": "/ɑːr/",
        "was": "/wɒz/", "on": "/ɒn/", "have": "/hæv/", "from": "/frɒm/", "we": "/wiː/",
        "be": "/biː/", "at": "/æt/", "one": "/wʌn/", "all": "/ɔːl/", "would": "/wʊd/",
        "there": "/ðeər/", "their": "/ðeər/", "what": "/wɒt/", "so": "/səʊ/",
        "up": "/ʌp/", "out": "/aʊt/", "about": "/əˈbaʊt/", "who": "/huː/",
        "which": "/wɪtʃ/", "when": "/wen/", "can": "/kæn/", "will": "/wɪl/",
        "other": "/ˈʌðər/", "into": "/ˈɪntuː/", "could": "/kʊd/", "time": "/taɪm/",
        "very": "/ˈveri/", "just": "/dʒʌst/", "than": "/ðæn/", "know": "/nəʊ/",
        "some": "/sʌm/", "people": "/ˈpiːpəl/", "through": "/θruː/",
        "between": "/bɪˈtwiːn/", "world": "/wɜːrld/", "also": "/ˈɔːlsəʊ/",
        "because": "/bɪˈkɒz/", "should": "/ʃʊd/", "these": "/ðiːz/",
        "important": "/ɪmˈpɔːrtənt/", "different": "/ˈdɪfrənt/",
        "understand": "/ˌʌndərˈstænd/", "experience": "/ɪkˈspɪriəns/",
        "opportunity": "/ˌɒpərˈtjuːnɪti/", "development": "/dɪˈveləpmənt/",
        "environment": "/ɪnˈvaɪrənmənt/", "knowledge": "/ˈnɒlɪdʒ/",
        "technology": "/tekˈnɒlədʒi/", "communication": "/kəˌmjuːnɪˈkeɪʃən/",
        "application": "/ˌæplɪˈkeɪʃən/", "information": "/ˌɪnfərˈmeɪʃən/",
        "education": "/ˌedʒuˈkeɪʃən/", "organization": "/ˌɔːrɡənaɪˈzeɪʃən/",
        "government": "/ˈɡʌvərnmənt/", "international": "/ˌɪntərˈnæʃənəl/",
        "performance": "/pərˈfɔːrməns/", "management": "/ˈmænɪdʒmənt/",
        "community": "/kəˈmjuːnɪti/", "accomplish": "/əˈkɒmplɪʃ/",
        "consequence": "/ˈkɒnsɪkwəns/", "significant": "/sɪɡˈnɪfɪkənt/",
        "entrepreneur": "/ˌɒntrəprəˈnɜːr/", "miscellaneous": "/ˌmɪsəˈleɪniəs/",
        "necessary": "/ˈnesəseri/", "immediately": "/ɪˈmiːdiətli/",
        "definitely": "/ˈdefɪnɪtli/", "separate": "/ˈseprət/",
        "occurred": "/əˈkɜːrd/", "existence": "/ɪɡˈzɪstəns/",
    ]
    
    private func getIPAPhonetic(for word: String) -> String {
        let lowercased = word.lowercased()
            .trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespaces))
        return commonIPA[lowercased] ?? ""
    }
    
    private func generatePronunciationGuide(word: String, language: String) -> String {
        // Currently returns empty — AI provides this field
        return ""
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