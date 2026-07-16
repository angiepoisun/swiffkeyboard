import Foundation

/// A single pinyin→Hanzi mapping. One pinyin key (e.g. "shi") commonly has
/// several homophone candidates (是/时/十/事/市…), which is exactly the
/// "pick the right character" interaction a Pinyin IME's candidate bar
/// exists for.
struct PinyinEntry {
    let pinyin: String
    let hanzi: String
    let frequency: Int
}

/// Simplified or Traditional candidates for typing Chinese by romanized
/// (tone-less) pinyin — either tapped key by key or swiped as a glide path
/// across the same QWERTY layout used to spell it. Unlike
/// `WordFrequencyDictionary`, a lookup key (pinyin) and its result (Hanzi)
/// are different strings, and one key can resolve to several candidates.
final class PinyinDictionary {
    private(set) var language: SupportedLanguage
    private var entriesByPinyin: [String: [PinyinEntry]] = [:]
    private var pinyinKeysByFirstLetter: [Character: [String]] = [:]
    private let trie = Trie()

    init(language: SupportedLanguage) {
        self.language = language
        load(language: language)
    }

    func reload(language: SupportedLanguage) {
        guard language != self.language else { return }
        self.language = language
        entriesByPinyin.removeAll()
        pinyinKeysByFirstLetter.removeAll()
        load(language: language)
    }

    private func load(language: SupportedLanguage) {
        let bundle = Bundle(for: PinyinDictionary.self)
        guard let url = bundle.url(forResource: language.wordListResourceName, withExtension: "txt"),
              let contents = try? String(contentsOf: url, encoding: .utf8) else { return }

        for line in contents.split(separator: "\n") {
            let parts = line.split(separator: "\t")
            guard parts.count >= 2 else { continue }
            let pinyin = String(parts[0]).lowercased()
            let hanzi = String(parts[1])
            let frequency = parts.count > 2 ? (Int(parts[2]) ?? 1) : 1
            add(pinyin: pinyin, hanzi: hanzi, frequency: frequency)
        }
    }

    private func add(pinyin: String, hanzi: String, frequency: Int) {
        guard !pinyin.isEmpty, !hanzi.isEmpty else { return }
        var entries = entriesByPinyin[pinyin] ?? []
        if entries.contains(where: { $0.hanzi == hanzi }) { return }
        entries.append(PinyinEntry(pinyin: pinyin, hanzi: hanzi, frequency: frequency))
        entries.sort { $0.frequency > $1.frequency }
        entriesByPinyin[pinyin] = entries

        if let first = pinyin.first {
            if pinyinKeysByFirstLetter[first]?.contains(pinyin) != true {
                pinyinKeysByFirstLetter[first, default: []].append(pinyin)
                trie.insert(pinyin)
            }
        }
    }

    /// All homophone/word candidates for one exact pinyin key, best first.
    func hanziCandidates(forExactPinyin pinyin: String) -> [String] {
        (entriesByPinyin[pinyin.lowercased()] ?? []).map(\.hanzi)
    }

    /// Best candidate per pinyin key that starts with `prefix`, for showing
    /// while the user is still typing/composing — exact-key homophones are
    /// all included, longer keys only contribute their top candidate so the
    /// bar doesn't fill up with every homophone of every longer word.
    func candidates(forPrefix prefix: String, limit: Int = 8) -> [String] {
        let prefix = prefix.lowercased()
        guard !prefix.isEmpty else { return [] }

        var results: [(hanzi: String, frequency: Int)] = []
        if let exact = entriesByPinyin[prefix] {
            for entry in exact {
                results.append((entry.hanzi, entry.frequency))
            }
        }
        for key in trie.words(withPrefix: prefix) where key != prefix {
            guard let best = entriesByPinyin[key]?.first else { continue }
            results.append((best.hanzi, best.frequency))
        }

        var seen = Set<String>()
        return results
            .sorted { $0.frequency > $1.frequency }
            .filter { seen.insert($0.hanzi).inserted }
            .prefix(limit)
            .map(\.hanzi)
    }
}

extension PinyinDictionary: GlideCandidateSource {
    func candidateKeys(startingWith letter: Character) -> [String] {
        pinyinKeysByFirstLetter[Character(letter.lowercased())] ?? []
    }

    func frequency(ofKey key: String) -> Int {
        entriesByPinyin[key.lowercased()]?.first?.frequency ?? 0
    }
}
