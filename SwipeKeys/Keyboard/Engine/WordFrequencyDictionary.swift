import Foundation

/// A language's word list, ranked by frequency, plus words the user has
/// typed often enough to "learn" (persisted in the shared App Group so
/// learning carries over between app launches).
final class WordFrequencyDictionary {
    private(set) var language: SupportedLanguage
    private var frequencyByWord: [String: Int] = [:]
    private var wordsByFirstLetter: [Character: [String]] = [:]
    /// wrongWord -> word the user corrected it to, so a swipe that keeps
    /// shape-matching to the wrong word can be steered right without
    /// needing repeated corrections (see `applyCorrections(to:)`).
    private var correctionByWrongWord: [String: String] = [:]
    let trie = Trie()

    init(language: SupportedLanguage) {
        self.language = language
        load(language: language)
    }

    func reload(language: SupportedLanguage) {
        guard language != self.language else { return }
        self.language = language
        frequencyByWord.removeAll()
        wordsByFirstLetter.removeAll()
        correctionByWrongWord.removeAll()
        load(language: language)
    }

    private func load(language: SupportedLanguage) {
        let bundle = Bundle(for: WordFrequencyDictionary.self)
        if let url = bundle.swipeKeysResourceURL(named: language.wordListResourceName, withExtension: "txt"),
           let contents = try? String(contentsOf: url, encoding: .utf8) {
            for line in contents.split(separator: "\n") {
                let parts = line.split(separator: " ")
                guard let word = parts.first.map(String.init), !word.isEmpty else { continue }
                let frequency = parts.count > 1 ? (Int(parts[1]) ?? 1) : 1
                add(word: word, frequency: frequency)
            }
        }

        loadLearnedWords()
        loadCorrections()
    }

    private func languageStorageKey() -> String {
        "\(language.rawValue):"
    }

    private func loadLearnedWords() {
        let learned = AppGroup.defaults.dictionary(forKey: AppGroup.Key.learnedWords) as? [String: Int] ?? [:]
        let prefix = languageStorageKey()
        for (key, count) in learned where key.hasPrefix(prefix) {
            let word = String(key.dropFirst(prefix.count))
            add(word: word, frequency: (frequencyByWord[word.lowercased()] ?? 500) + count * 50)
        }
    }

    private func loadCorrections() {
        let corrections = AppGroup.defaults.dictionary(forKey: AppGroup.Key.glideCorrections) as? [String: String] ?? [:]
        let prefix = languageStorageKey()
        for (key, correctedWord) in corrections where key.hasPrefix(prefix) {
            let wrongWord = String(key.dropFirst(prefix.count))
            correctionByWrongWord[wrongWord] = correctedWord
        }
    }

    private func add(word: String, frequency: Int) {
        let lower = word.lowercased()
        frequencyByWord[lower] = max(frequencyByWord[lower] ?? 0, frequency)
        guard let first = lower.first else { return }
        if wordsByFirstLetter[first]?.contains(lower) != true {
            wordsByFirstLetter[first, default: []].append(lower)
            trie.insert(lower)
        }
    }

    /// Persist that the user typed this word, boosting its rank next time.
    func learn(word: String) {
        let lower = word.lowercased()
        guard lower.count > 1 else { return }
        var learned = AppGroup.defaults.dictionary(forKey: AppGroup.Key.learnedWords) as? [String: Int] ?? [:]
        let key = languageStorageKey() + lower
        learned[key] = (learned[key] ?? 0) + 1
        AppGroup.defaults.set(learned, forKey: AppGroup.Key.learnedWords)
        add(word: lower, frequency: (frequencyByWord[lower] ?? 500) + 50)
    }

    /// Remembers that a swipe which shape-matched to `wrongWord` should
    /// have produced `correctedWord` instead, so `applyCorrections(to:)` can
    /// steer future results for the same confusable shape without the user
    /// having to correct it over and over. One correction is enough to
    /// take effect — this isn't a statistical model, it's "the user just
    /// told you the answer, believe them."
    func recordCorrection(from wrongWord: String, to correctedWord: String) {
        let wrong = wrongWord.lowercased()
        let corrected = correctedWord.lowercased()
        guard wrong != corrected else { return }
        var corrections = AppGroup.defaults.dictionary(forKey: AppGroup.Key.glideCorrections) as? [String: String] ?? [:]
        corrections[languageStorageKey() + wrong] = corrected
        AppGroup.defaults.set(corrections, forKey: AppGroup.Key.glideCorrections)
        correctionByWrongWord[wrong] = corrected
        learn(word: correctedWord)
    }

    /// Re-orders glide candidates so a previously-corrected word wins over
    /// whatever the raw shape/frequency score currently favors, as long as
    /// the corrected word is a plausible candidate at all (either already
    /// in the list, or a known word in this dictionary).
    func applyCorrections(to candidates: [String]) -> [String] {
        guard let top = candidates.first,
              let corrected = correctionByWrongWord[top.lowercased()],
              corrected != top.lowercased() else {
            return candidates
        }
        if let index = candidates.firstIndex(where: { $0.lowercased() == corrected }) {
            var reordered = candidates
            let promoted = reordered.remove(at: index)
            reordered.insert(promoted, at: 0)
            return reordered
        }
        if frequency(of: corrected) > 0 {
            return [corrected] + candidates
        }
        return candidates
    }

    func frequency(of word: String) -> Int {
        frequencyByWord[word.lowercased()] ?? 0
    }

    func words(startingWith letter: Character) -> [String] {
        wordsByFirstLetter[Character(letter.lowercased())] ?? []
    }

    /// Simple prefix autocomplete for tap-typing, ranked by frequency.
    func completions(forPrefix prefix: String, limit: Int = 3) -> [String] {
        guard !prefix.isEmpty else { return [] }
        return trie.words(withPrefix: prefix)
            .sorted { frequency(of: $0) > frequency(of: $1) }
            .prefix(limit)
            .map { $0 }
    }

    var allFirstLetters: [Character] {
        Array(wordsByFirstLetter.keys)
    }
}
