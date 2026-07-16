import Foundation

/// What `GlideTypingEngine` needs from a dictionary to score a swipe path:
/// candidate keys to try (pruned by starting letter) and a frequency to
/// rank them by. For Latin languages a "key" is the word itself. For Pinyin
/// input a "key" is the romanization (e.g. "nihao") — resolving that key to
/// actual Hanzi text is the caller's job, since one pinyin key can map to
/// several homophone candidates.
protocol GlideCandidateSource {
    func candidateKeys(startingWith letter: Character) -> [String]
    func frequency(ofKey key: String) -> Int
}

extension WordFrequencyDictionary: GlideCandidateSource {
    func candidateKeys(startingWith letter: Character) -> [String] {
        words(startingWith: letter)
    }

    func frequency(ofKey key: String) -> Int {
        frequency(of: key)
    }
}
