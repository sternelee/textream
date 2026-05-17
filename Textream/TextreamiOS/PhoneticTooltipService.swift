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

    /// Called when a result is ready
    var onResult: ((PhoneticResult?) -> Void)?

    private init() {}

    func fetchHint(for word: String, targetLanguage: String = "zh", source: PhoneticSource = .aiGenerated) {
        Task {
            let result = await fetchHintAsync(for: word, targetLanguage: targetLanguage, source: source)
            DispatchQueue.main.async {
                self.onResult?(result)
            }
        }
    }

    func fetchHintAsync(for word: String, targetLanguage: String = "zh", source: PhoneticSource = .aiGenerated) async -> PhoneticResult? {
        let displayWord = normalizedDisplayWord(from: word)
        guard !displayWord.isEmpty else { return nil }

        let key = cacheKey(word: displayWord, lang: targetLanguage, source: source)
        if let cached = cache[key] {
            return cached
        }

        let localIPA = getIPAPhonetic(for: displayWord)

        let resolved: PhoneticResult?
        switch source {
        case .localDictionary:
            resolved = await resolveLocalDictionaryHint(for: displayWord, targetLanguage: targetLanguage, localIPA: localIPA)
        case .aiGenerated:
            resolved = await resolveAIHint(for: displayWord, targetLanguage: targetLanguage, localIPA: localIPA)
        }

        if let resolved {
            cache[key] = resolved
        }
        return resolved
    }

    func clearCache() {
        cache.removeAll()
    }

    private func cacheKey(word: String, lang: String, source: PhoneticSource) -> String {
        "phonetic_\(source.rawValue)_\(lang)_\(word.lowercased())"
    }

    private func resolveLocalDictionaryHint(for word: String, targetLanguage: String, localIPA: IPALookup) async -> PhoneticResult? {
        if let localOnly = makeLocalOnlyResult(for: word, localIPA: localIPA) {
            return localOnly
        }
        return await fetchOnlineDictionaryHint(for: word, targetLanguage: targetLanguage, localIPA: localIPA)
    }

    private func resolveAIHint(for word: String, targetLanguage: String, localIPA: IPALookup) async -> PhoneticResult? {
        if AIScriptService.shared.hasAPIKey,
           let aiResult = await fetchAIHint(for: word, targetLanguage: targetLanguage, localIPA: localIPA) {
            return aiResult
        }

        if let onlineResult = await fetchOnlineDictionaryHint(for: word, targetLanguage: targetLanguage, localIPA: localIPA) {
            return onlineResult
        }

        return makeLocalOnlyResult(for: word, localIPA: localIPA)
    }

    private func makeLocalOnlyResult(for word: String, localIPA: IPALookup) -> PhoneticResult? {
        guard !localIPA.us.isEmpty || !localIPA.uk.isEmpty else { return nil }
        return PhoneticResult(
            word: word,
            phonetic: localIPA.us,
            phoneticUK: localIPA.uk,
            translation: "",
            pronunciation: ""
        )
    }

    private func fetchAIHint(for word: String, targetLanguage: String, localIPA: IPALookup) async -> PhoneticResult? {
        let parsed: (ipa: String, ukIPA: String, translation: String, pronunciation: String)? = await withCheckedContinuation { continuation in
            AIScriptService.shared.generatePhonetic(word: word, targetLanguage: targetLanguage) { result in
                switch result {
                case .success(let parsed):
                    continuation.resume(returning: parsed)
                case .failure:
                    continuation.resume(returning: nil)
                }
            }
        }

        guard let parsed else { return nil }

        let ipa = normalizeIPA(parsed.ipa) ?? localIPA.us
        let ukIPA = normalizeIPA(parsed.ukIPA) ?? localIPA.uk
        let translation = parsed.translation.trimmingCharacters(in: .whitespacesAndNewlines)
        let pronunciation = parsed.pronunciation.trimmingCharacters(in: .whitespacesAndNewlines)

        if ipa.isEmpty && ukIPA.isEmpty && translation.isEmpty && pronunciation.isEmpty {
            return nil
        }

        return PhoneticResult(
            word: word,
            phonetic: ipa,
            phoneticUK: ukIPA,
            translation: translation,
            pronunciation: pronunciation
        )
    }

    private func fetchOnlineDictionaryHint(for word: String, targetLanguage: String, localIPA: IPALookup) async -> PhoneticResult? {
        for candidate in lookupCandidates(for: word) {
            guard let encoded = candidate.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                  let url = URL(string: "https://api.dictionaryapi.dev/api/v2/entries/en/\(encoded)") else {
                continue
            }

            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    continue
                }

                let entries = try JSONDecoder().decode([DictionaryEntry].self, from: data)
                if let result = makeOnlineResult(from: entries, displayWord: word, targetLanguage: targetLanguage, localIPA: localIPA) {
                    return result
                }
            } catch {
                continue
            }
        }

        return nil
    }

    private func makeOnlineResult(from entries: [DictionaryEntry], displayWord: String, targetLanguage: String, localIPA: IPALookup) -> PhoneticResult? {
        guard let first = entries.first else { return nil }

        let phoneticCandidates = ([first.phonetic] + first.phonetics.map(\ .text))
            .compactMap { $0 }
            .compactMap(normalizeIPA)

        let primaryIPA = phoneticCandidates.first(where: { !$0.isEmpty }) ?? localIPA.us
        let secondaryIPA = phoneticCandidates.first(where: { !$0.isEmpty && $0 != primaryIPA }) ?? localIPA.uk

        let firstMeaning = first.meanings.first
        let firstDefinition = firstMeaning?.definitions.first
        let partOfSpeech = firstMeaning?.partOfSpeech?.trimmingCharacters(in: .whitespacesAndNewlines)
        let definitionText = firstDefinition?.definition?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let example = firstDefinition?.example?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        var meaning = definitionText
        if let partOfSpeech, !partOfSpeech.isEmpty, !definitionText.isEmpty {
            meaning = "\(partOfSpeech) · \(definitionText)"
        }

        let pronunciationGuide: String
        if !example.isEmpty {
            pronunciationGuide = "Example: \(example)"
        } else {
            pronunciationGuide = ""
        }

        if primaryIPA.isEmpty && secondaryIPA.isEmpty && meaning.isEmpty && pronunciationGuide.isEmpty {
            return nil
        }

        return PhoneticResult(
            word: displayWord,
            phonetic: primaryIPA,
            phoneticUK: secondaryIPA,
            translation: meaning,
            pronunciation: pronunciationGuide
        )
    }

    private func normalizedDisplayWord(from word: String) -> String {
        word
            .trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespacesAndNewlines))
            .replacingOccurrences(of: "^[‘’'\"]+|[‘’'\"]+$", with: "", options: .regularExpression)
            .replacingOccurrences(of: "[’']s$", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func lookupCandidates(for word: String) -> [String] {
        let trimmed = normalizedDisplayWord(from: word)
        guard !trimmed.isEmpty else { return [] }

        var candidates: [String] = [trimmed]
        let lowercased = trimmed.lowercased()
        if lowercased != trimmed {
            candidates.append(lowercased)
        }
        return Array(NSOrderedSet(array: candidates)) as? [String] ?? candidates
    }

    private func normalizeIPA(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("/") || trimmed.hasPrefix("[") {
            return trimmed
        }
        return "/\(trimmed)/"
    }

    private struct DictionaryEntry: Decodable {
        let word: String?
        let phonetic: String?
        let phonetics: [DictionaryPhonetic]
        let meanings: [DictionaryMeaning]
    }

    private struct DictionaryPhonetic: Decodable {
        let text: String?
    }

    private struct DictionaryMeaning: Decodable {
        let partOfSpeech: String?
        let definitions: [DictionaryDefinition]
    }

    private struct DictionaryDefinition: Decodable {
        let definition: String?
        let example: String?
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
        "iphone": .init(us: "/ˈaɪfoʊn/", uk: "/ˈaɪfəʊn/"),
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
