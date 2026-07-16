import Foundation

/// A language's word list, ranked by frequency, plus words the user has
/// typed often enough to "learn" (persisted in the shared App Group so
/// learning carries over between app launches).
final class WordFrequencyDictionary {
    private(set) var language: SupportedLanguage
    private var frequencyByWord: [String: Int] = [:]
    private var wordsByFirstLetter: [Character: [String]] = [:]
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
        load(language: language)
    }

    private func load(language: SupportedLanguage) {
        let bundle = Bundle(for: WordFrequencyDictionary.self)
        if let url = bundle.url(forResource: language.wordListResourceName, withExtension: "txt"),
           let contents = try? String(contentsOf: url, encoding: .utf8) {
            for line in contents.split(separator: "\n") {
                let parts = line.split(separator: " ")
                guard let word = parts.first.map(String.init), !word.isEmpty else { continue }
                let frequency = parts.count > 1 ? (Int(parts[1]) ?? 1) : 1
                add(word: word, frequency: frequency)
            }
        }

        loadLearnedWords()
    }

    private func learnedStorageKey() -> String {
        "\(language.rawValue):"
    }

    private func loadLearnedWords() {
        let learned = AppGroup.defaults.dictionary(forKey: AppGroup.Key.learnedWords) as? [String: Int] ?? [:]
        let prefix = learnedStorageKey()
        for (key, count) in learned where key.hasPrefix(prefix) {
            let word = String(key.dropFirst(prefix.count))
            add(word: word, frequency: (frequencyByWord[word.lowercased()] ?? 500) + count * 50)
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
        let key = learnedStorageKey() + lower
        learned[key] = (learned[key] ?? 0) + 1
        AppGroup.defaults.set(learned, forKey: AppGroup.Key.learnedWords)
        add(word: lower, frequency: (frequencyByWord[lower] ?? 500) + 50)
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
