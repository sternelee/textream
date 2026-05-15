//
//  PhoneticTooltipService.swift
//  TextreamiOS
//
//  Fetch phonetic hints (IPA + translation) for a word.
//

import Foundation

struct PhoneticResult {
    let word: String
    let phonetic: String
    let phoneticUK: String
    let translation: String
    let pronunciation: String
}

@Observable
class PhoneticTooltipService {
    static let shared = PhoneticTooltipService()

    private var cache: [String: PhoneticResult] = [:]
    private var pendingRequests: Set<String> = []

    /// Called when a result is ready
    var onResult: ((PhoneticResult?) -> Void)?

    private init() {}

    func fetchHint(for word: String, targetLanguage: String = "zh") {
        let key = cacheKey(word: word, lang: targetLanguage)

        if let cached = cache[key] {
            DispatchQueue.main.async { self.onResult?(cached) }
            return
        }

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
            DispatchQueue.main.async { self.onResult?(localResult) }
        }

        guard !pendingRequests.contains(key) else { return }
        pendingRequests.insert(key)

        AIScriptService.shared.generatePhonetic(word: word, targetLanguage: targetLanguage) { [weak self] result in
            self?.pendingRequests.remove(key)
            guard let self else { return }
            switch result {
            case .success(let parsed):
                var ipa = parsed.ipa
                let ukIPA = parsed.ukIPA
                var translation = parsed.translation
                var pronunciation = parsed.pronunciation
                if ipa.isEmpty && !localIPA.us.isEmpty {
                    ipa = localIPA.us
                }
                if translation.isEmpty && pronunciation.isEmpty && !localIPA.us.isEmpty {
                    return
                }
                let final = PhoneticResult(
                    word: word,
                    phonetic: ipa,
                    phoneticUK: ukIPA,
                    translation: translation,
                    pronunciation: pronunciation
                )
                self.cache[key] = final
                DispatchQueue.main.async { self.onResult?(final) }
            case .failure:
                if !localIPA.us.isEmpty { return }
                DispatchQueue.main.async { self.onResult?(nil) }
            }
        }
    }

    func fetchHintAsync(for word: String, targetLanguage: String = "zh") async -> PhoneticResult? {
        await withCheckedContinuation { continuation in
            onResult = { res in
                continuation.resume(returning: res)
            }
            fetchHint(for: word, targetLanguage: targetLanguage)
        }
    }

    func clearCache() {
        cache.removeAll()
    }

    private func cacheKey(word: String, lang: String) -> String {
        "phonetic_\(lang)_\(word.lowercased())"
    }

    private struct IPALookup { let us: String; let uk: String }

    private let commonIPA: [String: IPALookup] = [
        "the": .init(us: "/ðə/", uk: "/ðə/"),
        "a": .init(us: "/ə/", uk: "/ə/"),
        "an": .init(us: "/ən/", uk: "/ən/"),
        "and": .init(us: "/ænd/", uk: "/ænd/"),
        "or": .init(us: "/ɔːr/", uk: "/ɔː/"),
        "of": .init(us: "/ʌv/", uk: "/ɒv/"),
        "to": .init(us: "/tuː/", uk: "/tuː/"),
        "in": .init(us: "/ɪn/", uk: "/ɪn/"),
        "for": .init(us: "/fɔːr/", uk: "/fɔː/"),
        "with": .init(us: "/wɪð/", uk: "/wɪð/"),
        "is": .init(us: "/ɪz/", uk: "/ɪz/"),
        "it": .init(us: "/ɪt/", uk: "/ɪt/"),
        "that": .init(us: "/ðæt/", uk: "/ðæt/"),
        "this": .init(us: "/ðɪs/", uk: "/ðɪs/"),
        "are": .init(us: "/ɑːr/", uk: "/ɑː/"),
        "was": .init(us: "/wɒz/", uk: "/wɒz/"),
        "on": .init(us: "/ɒn/", uk: "/ɒn/"),
        "have": .init(us: "/hæv/", uk: "/hæv/"),
        "from": .init(us: "/frɒm/", uk: "/frɒm/"),
        "we": .init(us: "/wiː/", uk: "/wiː/"),
        "be": .init(us: "/biː/", uk: "/biː/"),
        "at": .init(us: "/æt/", uk: "/æt/"),
        "one": .init(us: "/wʌn/", uk: "/wʌn/"),
        "all": .init(us: "/ɔːl/", uk: "/ɔːl/"),
        "would": .init(us: "/wʊd/", uk: "/wʊd/"),
        "there": .init(us: "/ðeər/", uk: "/ðeə/"),
        "their": .init(us: "/ðeər/", uk: "/ðeə/"),
        "what": .init(us: "/wɒt/", uk: "/wɒt/"),
        "so": .init(us: "/səʊ/", uk: "/səʊ/"),
        "up": .init(us: "/ʌp/", uk: "/ʌp/"),
        "out": .init(us: "/aʊt/", uk: "/aʊt/"),
        "about": .init(us: "/əˈbaʊt/", uk: "/əˈbaʊt/"),
        "who": .init(us: "/huː/", uk: "/huː/"),
        "which": .init(us: "/wɪtʃ/", uk: "/wɪtʃ/"),
        "when": .init(us: "/wen/", uk: "/wen/"),
        "can": .init(us: "/kæn/", uk: "/kæn/"),
        "will": .init(us: "/wɪl/", uk: "/wɪl/"),
        "other": .init(us: "/ˈʌðər/", uk: "/ˈʌðə/"),
        "into": .init(us: "/ˈɪntuː/", uk: "/ˈɪntuː/"),
        "could": .init(us: "/kʊd/", uk: "/kʊd/"),
        "time": .init(us: "/taɪm/", uk: "/taɪm/"),
        "very": .init(us: "/ˈveri/", uk: "/ˈveri/"),
        "just": .init(us: "/dʒʌst/", uk: "/dʒʌst/"),
        "than": .init(us: "/ðæn/", uk: "/ðæn/"),
        "know": .init(us: "/nəʊ/", uk: "/nəʊ/"),
        "some": .init(us: "/sʌm/", uk: "/sʌm/"),
        "should": .init(us: "/ʃʊd/", uk: "/ʃʊd/"),
        "these": .init(us: "/ðiːz/", uk: "/ðiːz/"),
        "entrepreneur": .init(us: "/ˌɒntrəprəˈnɜːr/", uk: "/ˌɒntrəprəˈnɜː/"),
        "miscellaneous": .init(us: "/ˌmɪsəˈleɪniəs/", uk: "/ˌmɪsəˈleɪniəs/"),
        "necessary": .init(us: "/ˈnesəseri/", uk: "/ˈnesəsəri/"),
        "immediately": .init(us: "/ɪˈmiːdiətli/", uk: "/ɪˈmiːdiətli/"),
        "definitely": .init(us: "/ˈdefɪnɪtli/", uk: "/ˈdefɪnɪtli/"),
        "separate": .init(us: "/ˈseprət/", uk: "/ˈsepərət/"),
        "occurred": .init(us: "/əˈkɜːrd/", uk: "/əˈkɜːd/"),
        "existence": .init(us: "/ɪɡˈzɪstəns/", uk: "/ɪɡˈzɪstəns/"),
        "important": .init(us: "/ɪmˈpɔːrtənt/", uk: "/ɪmˈpɔːtənt/"),
        "different": .init(us: "/ˈdɪfrənt/", uk: "/ˈdɪfrənt/"),
        "understand": .init(us: "/ˌʌndərˈstænd/", uk: "/ˌʌndəˈstænd/"),
        "experience": .init(us: "/ɪkˈspɪriəns/", uk: "/ɪkˈspɪəriəns/"),
        "opportunity": .init(us: "/ˌɒpərˈtjuːnɪti/", uk: "/ˌɒpəˈtjuːnɪti/"),
        "development": .init(us: "/dɪˈveləpmənt/", uk: "/dɪˈveləpmənt/"),
        "environment": .init(us: "/ɪnˈvaɪrənmənt/", uk: "/ɪnˈvaɪrənmənt/"),
        "knowledge": .init(us: "/ˈnɒlɪdʒ/", uk: "/ˈnɒlɪdʒ/"),
        "technology": .init(us: "/tekˈnɒlədʒi/", uk: "/tekˈnɒlədʒi/"),
        "communication": .init(us: "/kəˌmjuːnɪˈkeɪʃən/", uk: "/kəˌmjuːnɪˈkeɪʃən/"),
        "application": .init(us: "/ˌæplɪˈkeɪʃən/", uk: "/ˌæplɪˈkeɪʃən/"),
        "information": .init(us: "/ˌɪnfərˈmeɪʃən/", uk: "/ˌɪnfəˈmeɪʃən/"),
        "education": .init(us: "/ˌedʒuˈkeɪʃən/", uk: "/ˌedʒʊˈkeɪʃən/"),
        "organization": .init(us: "/ˌɔːrɡənaɪˈzeɪʃən/", uk: "/ˌɔːɡənaɪˈzeɪʃən/"),
        "government": .init(us: "/ˈɡʌvərnmənt/", uk: "/ˈɡʌvənmənt/"),
        "international": .init(us: "/ˌɪntərˈnæʃənəl/", uk: "/ˌɪntəˈnæʃənəl/"),
        "performance": .init(us: "/pərˈfɔːrməns/", uk: "/pəˈfɔːməns/"),
        "management": .init(us: "/ˈmænɪdʒmənt/", uk: "/ˈmænɪdʒmənt/"),
        "community": .init(us: "/kəˈmjuːnɪti/", uk: "/kəˈmjuːnɪti/"),
        "accomplish": .init(us: "/əˈkɒmplɪʃ/", uk: "/əˈkɒmplɪʃ/"),
        "consequence": .init(us: "/ˈkɒnsɪkwəns/", uk: "/ˈkɒnsɪkwəns/"),
        "significant": .init(us: "/sɪɡˈnɪfɪkənt/", uk: "/sɪɡˈnɪfɪkənt/"),
        "people": .init(us: "/ˈpiːpəl/", uk: "/ˈpiːpəl/"),
        "through": .init(us: "/θruː/", uk: "/θruː/"),
        "between": .init(us: "/bɪˈtwiːn/", uk: "/bɪˈtwiːn/"),
        "world": .init(us: "/wɜːrld/", uk: "/wɜːld/"),
        "also": .init(us: "/ˈɔːlsəʊ/", uk: "/ˈɔːlsəʊ/"),
        "because": .init(us: "/bɪˈkɒz/", uk: "/bɪˈkɒz/"),
        "presentation": .init(us: "/ˌprɛzənˈteɪʃən/", uk: "/ˌprɛzənˈteɪʃən/"),
        "specifically": .init(us: "/spəˈsɪfɪkli/", uk: "/spəˈsɪfɪkli/"),
        "acknowledge": .init(us: "/əkˈnɒlɪdʒ/", uk: "/əkˈnɒlɪdʒ/"),
        "question": .init(us: "/ˈkwɛstʃən/", uk: "/ˈkwɛstʃən/"),
        "determine": .init(us: "/dɪˈtɜːrmɪn/", uk: "/dɪˈtɜːmɪn/"),
        "recognize": .init(us: "/ˈrekəɡnaɪz/", uk: "/ˈrekəɡnaɪz/"),
        "particular": .init(us: "/pərˈtɪkjʊlər/", uk: "/pəˈtɪkjʊlə/"),
        "category": .init(us: "/ˈkætəɡɔːri/", uk: "/ˈkætəɡəri/"),
        "ensure": .init(us: "/ɪnˈʃʊr/", uk: "/ɪnˈʃʊə/"),
        "examine": .init(us: "/ɪɡˈzæmɪn/", uk: "/ɪɡˈzæmɪn/"),
        "achieve": .init(us: "/əˈtʃiːv/", uk: "/əˈtʃiːv/"),
        "recommend": .init(us: "/ˌrekəˈmend/", uk: "/ˌrekəˈmend/"),
        "perspective": .init(us: "/pərˈspektɪv/", uk: "/pəˈspektɪv/"),
        "advantage": .init(us: "/ədˈvɒntɪdʒ/", uk: "/ədˈvɑːntɪdʒ/"),
        "fundamental": .init(us: "/ˌfʌndəˈmentəl/", uk: "/ˌfʌndəˈmentəl/"),
        "however": .init(us: "/haʊˈevər/", uk: "/haʊˈevə/"),
        "obviously": .init(us: "/ˈɒbviəsli/", uk: "/ˈɒbviəsli/"),
        "innovation": .init(us: "/ˌɪnəˈveɪʃən/", uk: "/ˌɪnəˈveɪʃən/"),
        "implement": .init(us: "/ˈɪmplɪment/", uk: "/ˈɪmplɪment/"),
        "comprehensive": .init(us: "/ˌkɒmprɪˈhensɪv/", uk: "/ˌkɒmprɪˈhensɪv/"),
        "absolutely": .init(us: "/ˌæbsəˈluːtli/", uk: "/ˌæbsəˈluːtli/"),
        "appropriate": .init(us: "/əˈprəʊpriət/", uk: "/əˈprəʊpriət/"),
        "conscious": .init(us: "/ˈkɒnʃəs/", uk: "/ˈkɒnʃəs/"),
        "exaggerate": .init(us: "/ɪɡˈzædʒəreɪt/", uk: "/ɪɡˈzædʒəreɪt/"),
        "mysterious": .init(us: "/mɪˈstɪəriəs/", uk: "/mɪˈstɪəriəs/"),
        "sophisticated": .init(us: "/səˈfɪstɪkeɪtɪd/", uk: "/səˈfɪstɪkeɪtɪd/"),
        "phenomenon": .init(us: "/fɪˈnɒmɪnən/", uk: "/fɪˈnɒmɪnən/"),
        "vocabulary": .init(us: "/vəˈkæbjʊləri/", uk: "/vəˈkæbjʊləri/"),
        "prerequisite": .init(us: "/priːˈrekwɪzɪt/", uk: "/priːˈrekwɪzɪt/"),
        "wednesday": .init(us: "/ˈwenzdeɪ/", uk: "/ˈwenzdeɪ/"),
        "recipe": .init(us: "/ˈresɪpi/", uk: "/ˈresɪpi/"),
        "island": .init(us: "/ˈaɪlənd/", uk: "/ˈaɪlənd/"),
        "colonel": .init(us: "/ˈkɜːrnl/", uk: "/ˈkɜːnl/"),
        "choir": .init(us: "/ˈkwaɪər/", uk: "/ˈkwaɪə/"),
        "sword": .init(us: "/sɔːrd/", uk: "/sɔːd/"),
        "schedule": .init(us: "/ˈskedʒuːl/", uk: "/ˈʃeːdjuːl/"),
        "comfortable": .init(us: "/ˈkʌmftəbəl/", uk: "/ˈkʌmftəbəl/"),
        "temperature": .init(us: "/ˈtemprətʃər/", uk: "/ˈtemprətʃə/"),
    ]

    private func getIPAPhonetic(for word: String) -> IPALookup {
        let lowercased = word.lowercased()
            .trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespaces))
        return commonIPA[lowercased] ?? IPALookup(us: "", uk: "")
    }
}
