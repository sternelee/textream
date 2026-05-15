//
//  PhoneticTooltipView.swift
//  Textream
//
//  Floating tooltip showing phonetic hint for a difficult word.
//

import SwiftUI

struct PhoneticResult {
    let word: String
    let phonetic: String       // IPA (US variant, or general)
    let phoneticUK: String     // IPA (UK variant)
    let translation: String   // Native language translation
    let pronunciation: String // Approximate pronunciation guide
}

@Observable
class PhoneticTooltipService {
    static let shared = PhoneticTooltipService()
    
    private var cache: [String: PhoneticResult] = [:]
    private var pendingRequests: Set<String> = Set<String>()
    
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
        
        // Check local IPA dictionary first for instant response
        let localIPA = getIPAPhonetic(for: word)
        if !localIPA.us.isEmpty || !localIPA.uk.isEmpty {
            let localResult = PhoneticResult(
                word: word,
                phonetic: localIPA.us,
                phoneticUK: localIPA.uk,
                translation: "",
                pronunciation: ""
            )
            cache[key] = localResult
            DispatchQueue.main.async {
                self.onResult?(localResult)
            }
            // Still fetch AI for full data (translation + pronunciation)
            // but user sees IPA instantly
        }
        
        // Avoid duplicate requests
        guard !pendingRequests.contains(key) else { return }
        pendingRequests.insert(key)
        
        let settings = NotchSettings.shared
        let targetLanguage = settings.nativeLanguage
        
        // Always use AI for complete data (translation + pronunciation)
        fetchAIGenerated(word: word, targetLanguage: targetLanguage) { [weak self] result in
            self?.pendingRequests.remove(key)
            guard let result = result, let self else {
                self?.onResult?(nil)
                return
            }
            // Merge: prefer AI data, but keep local IPA if AI returns empty
            var finalResult = result
            if finalResult.phonetic.isEmpty && !localIPA.us.isEmpty {
                finalResult = PhoneticResult(
                    word: result.word,
                    phonetic: localIPA.us,
                    phoneticUK: localIPA.uk.isEmpty ? result.phoneticUK : localIPA.uk,
                    translation: result.translation,
                    pronunciation: result.pronunciation
                )
            }
            self.cache[key] = finalResult
            DispatchQueue.main.async {
                self.onResult?(finalResult)
            }
        }
    }
    
    /// Clear cache
    func clearCache() {
        cache.removeAll()
    }
    
    private func cacheKey(word: String) -> String {
        let lang = NotchSettings.shared.nativeLanguage
        return "phonetic_\(lang)_\(word.lowercased())"
    }
    
    // MARK: - Local IPA Dictionary
    
    private struct IPALookup {
        let us: String   // American English IPA
        let uk: String   // British English IPA
    }
    
    private let commonIPA: [String: IPALookup] = [
        // High-frequency function words
        "the": IPALookup(us: "/ðə/", uk: "/ðə/"),
        "a": IPALookup(us: "/ə/", uk: "/ə/"),
        "an": IPALookup(us: "/ən/", uk: "/ən/"),
        "and": IPALookup(us: "/ænd/", uk: "/ænd/"),
        "or": IPALookup(us: "/ɔːr/", uk: "/ɔː/"),
        "of": IPALookup(us: "/ʌv/", uk: "/ɒv/"),
        "to": IPALookup(us: "/tuː/", uk: "/tuː/"),
        "in": IPALookup(us: "/ɪn/", uk: "/ɪn/"),
        "for": IPALookup(us: "/fɔːr/", uk: "/fɔː/"),
        "with": IPALookup(us: "/wɪð/", uk: "/wɪð/"),
        "is": IPALookup(us: "/ɪz/", uk: "/ɪz/"),
        "it": IPALookup(us: "/ɪt/", uk: "/ɪt/"),
        "that": IPALookup(us: "/ðæt/", uk: "/ðæt/"),
        "this": IPALookup(us: "/ðɪs/", uk: "/ðɪs/"),
        "are": IPALookup(us: "/ɑːr/", uk: "/ɑː/"),
        "was": IPALookup(us: "/wɒz/", uk: "/wɒz/"),
        "on": IPALookup(us: "/ɒn/", uk: "/ɒn/"),
        "have": IPALookup(us: "/hæv/", uk: "/hæv/"),
        "from": IPALookup(us: "/frɒm/", uk: "/frɒm/"),
        "we": IPALookup(us: "/wiː/", uk: "/wiː/"),
        "be": IPALookup(us: "/biː/", uk: "/biː/"),
        "at": IPALookup(us: "/æt/", uk: "/æt/"),
        "one": IPALookup(us: "/wʌn/", uk: "/wʌn/"),
        "all": IPALookup(us: "/ɔːl/", uk: "/ɔːl/"),
        "would": IPALookup(us: "/wʊd/", uk: "/wʊd/"),
        "there": IPALookup(us: "/ðeər/", uk: "/ðeə/"),
        "their": IPALookup(us: "/ðeər/", uk: "/ðeə/"),
        "what": IPALookup(us: "/wɒt/", uk: "/wɒt/"),
        "so": IPALookup(us: "/səʊ/", uk: "/səʊ/"),
        "up": IPALookup(us: "/ʌp/", uk: "/ʌp/"),
        "out": IPALookup(us: "/aʊt/", uk: "/aʊt/"),
        "about": IPALookup(us: "/əˈbaʊt/", uk: "/əˈbaʊt/"),
        "who": IPALookup(us: "/huː/", uk: "/huː/"),
        "which": IPALookup(us: "/wɪtʃ/", uk: "/wɪtʃ/"),
        "when": IPALookup(us: "/wen/", uk: "/wen/"),
        "can": IPALookup(us: "/kæn/", uk: "/kæn/"),
        "will": IPALookup(us: "/wɪl/", uk: "/wɪl/"),
        "other": IPALookup(us: "/ˈʌðər/", uk: "/ˈʌðə/"),
        "into": IPALookup(us: "/ˈɪntuː/", uk: "/ˈɪntuː/"),
        "could": IPALookup(us: "/kʊd/", uk: "/kʊd/"),
        "time": IPALookup(us: "/taɪm/", uk: "/taɪm/"),
        "very": IPALookup(us: "/ˈveri/", uk: "/ˈveri/"),
        "just": IPALookup(us: "/dʒʌst/", uk: "/dʒʌst/"),
        "than": IPALookup(us: "/ðæn/", uk: "/ðæn/"),
        "know": IPALookup(us: "/nəʊ/", uk: "/nəʊ/"),
        "some": IPALookup(us: "/sʌm/", uk: "/sʌm/"),
        "should": IPALookup(us: "/ʃʊd/", uk: "/ʃʊd/"),
        "these": IPALookup(us: "/ðiːz/", uk: "/ðiːz/"),
        
        // Difficult / commonly mispronounced words
        "annotate": IPALookup(us: "/ˈænəˌteɪt/", uk: "/ˈænəteɪt/"),
        "entrepreneur": IPALookup(us: "/ˌɒntrəprəˈnɜːr/", uk: "/ˌɒntrəprəˈnɜː/"),
        "miscellaneous": IPALookup(us: "/ˌmɪsəˈleɪniəs/", uk: "/ˌmɪsəˈleɪniəs/"),
        "necessary": IPALookup(us: "/ˈnesəseri/", uk: "/ˈnesəsəri/"),
        "immediately": IPALookup(us: "/ɪˈmiːdiətli/", uk: "/ɪˈmiːdiətli/"),
        "definitely": IPALookup(us: "/ˈdefɪnɪtli/", uk: "/ˈdefɪnɪtli/"),
        "separate": IPALookup(us: "/ˈseprət/", uk: "/ˈsepərət/"),
        "occurred": IPALookup(us: "/əˈkɜːrd/", uk: "/əˈkɜːd/"),
        "existence": IPALookup(us: "/ɪɡˈzɪstəns/", uk: "/ɪɡˈzɪstəns/"),
        "important": IPALookup(us: "/ɪmˈpɔːrtənt/", uk: "/ɪmˈpɔːtənt/"),
        "different": IPALookup(us: "/ˈdɪfrənt/", uk: "/ˈdɪfrənt/"),
        "understand": IPALookup(us: "/ˌʌndərˈstænd/", uk: "/ˌʌndəˈstænd/"),
        "experience": IPALookup(us: "/ɪkˈspɪriəns/", uk: "/ɪkˈspɪəriəns/"),
        "opportunity": IPALookup(us: "/ˌɒpərˈtjuːnɪti/", uk: "/ˌɒpəˈtjuːnɪti/"),
        "development": IPALookup(us: "/dɪˈveləpmənt/", uk: "/dɪˈveləpmənt/"),
        "environment": IPALookup(us: "/ɪnˈvaɪrənmənt/", uk: "/ɪnˈvaɪrənmənt/"),
        "knowledge": IPALookup(us: "/ˈnɒlɪdʒ/", uk: "/ˈnɒlɪdʒ/"),
        "technology": IPALookup(us: "/tekˈnɒlədʒi/", uk: "/tekˈnɒlədʒi/"),
        "communication": IPALookup(us: "/kəˌmjuːnɪˈkeɪʃən/", uk: "/kəˌmjuːnɪˈkeɪʃən/"),
        "application": IPALookup(us: "/ˌæplɪˈkeɪʃən/", uk: "/ˌæplɪˈkeɪʃən/"),
        "information": IPALookup(us: "/ˌɪnfərˈmeɪʃən/", uk: "/ˌɪnfəˈmeɪʃən/"),
        "education": IPALookup(us: "/ˌedʒuˈkeɪʃən/", uk: "/ˌedʒʊˈkeɪʃən/"),
        "organization": IPALookup(us: "/ˌɔːrɡənaɪˈzeɪʃən/", uk: "/ˌɔːɡənaɪˈzeɪʃən/"),
        "government": IPALookup(us: "/ˈɡʌvərnmənt/", uk: "/ˈɡʌvənmənt/"),
        "international": IPALookup(us: "/ˌɪntərˈnæʃənəl/", uk: "/ˌɪntəˈnæʃənəl/"),
        "performance": IPALookup(us: "/pərˈfɔːrməns/", uk: "/pəˈfɔːməns/"),
        "management": IPALookup(us: "/ˈmænɪdʒmənt/", uk: "/ˈmænɪdʒmənt/"),
        "community": IPALookup(us: "/kəˈmjuːnɪti/", uk: "/kəˈmjuːnɪti/"),
        "accomplish": IPALookup(us: "/əˈkɒmplɪʃ/", uk: "/əˈkɒmplɪʃ/"),
        "consequence": IPALookup(us: "/ˈkɒnsɪkwəns/", uk: "/ˈkɒnsɪkwəns/"),
        "significant": IPALookup(us: "/sɪɡˈnɪfɪkənt/", uk: "/sɪɡˈnɪfɪkənt/"),
        "people": IPALookup(us: "/ˈpiːpəl/", uk: "/ˈpiːpəl/"),
        "through": IPALookup(us: "/θruː/", uk: "/θruː/"),
        "between": IPALookup(us: "/bɪˈtwiːn/", uk: "/bɪˈtwiːn/"),
        "world": IPALookup(us: "/wɜːrld/", uk: "/wɜːld/"),
        "also": IPALookup(us: "/ˈɔːlsəʊ/", uk: "/ˈɔːlsəʊ/"),
        "because": IPALookup(us: "/bɪˈkɒz/", uk: "/bɪˈkɒz/"),
        "presentation": IPALookup(us: "/ˌprɛzənˈteɪʃən/", uk: "/ˌprɛzənˈteɪʃən/"),
        "specifically": IPALookup(us: "/spəˈsɪfɪkli/", uk: "/spəˈsɪfɪkli/"),
        "acknowledge": IPALookup(us: "/əkˈnɒlɪdʒ/", uk: "/əkˈnɒlɪdʒ/"),
        "question": IPALookup(us: "/ˈkwɛstʃən/", uk: "/ˈkwɛstʃən/"),
        "determine": IPALookup(us: "/dɪˈtɜːrmɪn/", uk: "/dɪˈtɜːmɪn/"),
        "recognize": IPALookup(us: "/ˈrekəɡnaɪz/", uk: "/ˈrekəɡnaɪz/"),
        "particular": IPALookup(us: "/pərˈtɪkjʊlər/", uk: "/pəˈtɪkjʊlə/"),
        "category": IPALookup(us: "/ˈkætəɡɔːri/", uk: "/ˈkætəɡəri/"),
        "ensure": IPALookup(us: "/ɪnˈʃʊr/", uk: "/ɪnˈʃʊə/"),
        "examine": IPALookup(us: "/ɪɡˈzæmɪn/", uk: "/ɪɡˈzæmɪn/"),
        "achieve": IPALookup(us: "/əˈtʃiːv/", uk: "/əˈtʃiːv/"),
        "recommend": IPALookup(us: "/ˌrekəˈmend/", uk: "/ˌrekəˈmend/"),
        "perspective": IPALookup(us: "/pərˈspektɪv/", uk: "/pəˈspektɪv/"),
        "advantage": IPALookup(us: "/ədˈvɒntɪdʒ/", uk: "/ədˈvɑːntɪdʒ/"),
        "fundamental": IPALookup(us: "/ˌfʌndəˈmentəl/", uk: "/ˌfʌndəˈmentəl/"),
        "however": IPALookup(us: "/haʊˈevər/", uk: "/haʊˈevə/"),
        "obviously": IPALookup(us: "/ˈɒbviəsli/", uk: "/ˈɒbviəsli/"),
        "innovation": IPALookup(us: "/ˌɪnəˈveɪʃən/", uk: "/ˌɪnəˈveɪʃən/"),
        "implement": IPALookup(us: "/ˈɪmplɪment/", uk: "/ˈɪmplɪment/"),
        "comprehensive": IPALookup(us: "/ˌkɒmprɪˈhensɪv/", uk: "/ˌkɒmprɪˈhensɪv/"),
        "absolutely": IPALookup(us: "/ˌæbsəˈluːtli/", uk: "/ˌæbsəˈluːtli/"),
        "appropriate": IPALookup(us: "/əˈprəʊpriət/", uk: "/əˈprəʊpriət/"),
        "conscious": IPALookup(us: "/ˈkɒnʃəs/", uk: "/ˈkɒnʃəs/"),
        "exaggerate": IPALookup(us: "/ɪɡˈzædʒəreɪt/", uk: "/ɪɡˈzædʒəreɪt/"),
        "mysterious": IPALookup(us: "/mɪˈstɪəriəs/", uk: "/mɪˈstɪəriəs/"),
        "sophisticated": IPALookup(us: "/səˈfɪstɪkeɪtɪd/", uk: "/səˈfɪstɪkeɪtɪd/"),
        "phenomenon": IPALookup(us: "/fɪˈnɒmɪnən/", uk: "/fɪˈnɒmɪnən/"),
        "vocabulary": IPALookup(us: "/vəˈkæbjʊləri/", uk: "/vəˈkæbjʊləri/"),
        "prerequisite": IPALookup(us: "/priːˈrekwɪzɪt/", uk: "/priːˈrekwɪzɪt/"),
        "Wednesday": IPALookup(us: "/ˈwenzdeɪ/", uk: "/ˈwenzdeɪ/"),
        "recipe": IPALookup(us: "/ˈresɪpi/", uk: "/ˈresɪpi/"),
        "island": IPALookup(us: "/ˈaɪlənd/", uk: "/ˈaɪlənd/"),
        "colonel": IPALookup(us: "/ˈkɜːrnl/", uk: "/ˈkɜːnl/"),
        "choir": IPALookup(us: "/ˈkwaɪər/", uk: "/ˈkwaɪə/"),
        "sword": IPALookup(us: "/sɔːrd/", uk: "/sɔːd/"),
        "schedule": IPALookup(us: "/ˈskedʒuːl/", uk: "/ˈʃeːdjuːl/"),
        "comfortable": IPALookup(us: "/ˈkʌmftəbəl/", uk: "/ˈkʌmftəbəl/"),
        "temperature": IPALookup(us: "/ˈtemprətʃər/", uk: "/ˈtemprətʃə/"),
    ]
    
    private func getIPAPhonetic(for word: String) -> IPALookup {
        let lowercased = word.lowercased()
            .trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespaces))
        if let lookup = commonIPA[lowercased] {
            return lookup
        }
        return IPALookup(us: "", uk: "")
    }
    
    // MARK: - AI Generated
    
    private func fetchAIGenerated(word: String, targetLanguage: String, completion: @escaping (PhoneticResult?) -> Void) {
        AIScriptService.shared.generatePhonetic(word: word, targetLanguage: targetLanguage) { result in
            switch result {
            case .success(let parsed):
                let phoneticResult = PhoneticResult(
                    word: word,
                    phonetic: parsed.ipa,
                    phoneticUK: parsed.ukIPA,
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
}