import UIKit

/// Wraps `UITextChecker` — the one system-dictionary API Apple actually
/// exposes to third-party keyboard extensions without requiring Full
/// Access. It's the engine behind system-wide spell-check and
/// autocomplete, and `learnWord`/`unlearnWord` write into the device's
/// shared user dictionary, available to every app's text checker, not
/// just this one.
///
/// What this can't do: there's no API to enumerate "all words starting
/// with X", so it can't replace the curated word list `GlideTypingEngine`
/// scores swipe paths against — that pool has to be enumerable. Nor is
/// there any way to read from or write into Apple's own QuickType
/// prediction model; that stays private to the system keyboard. What it
/// does add: real dictionary-quality tap-typing completions, and learning
/// that persists system-wide instead of only inside this app's storage.
enum SystemDictionary {
    private static let checker = UITextChecker()

    static func completions(forPrefix prefix: String, languageCode: String, limit: Int = 5) -> [String] {
        guard !prefix.isEmpty else { return [] }
        let range = NSRange(location: 0, length: prefix.utf16.count)
        guard let results = checker.completions(forPartialWordRange: range, in: prefix, language: languageCode) else {
            return []
        }
        return Array(results.prefix(limit))
    }

    static func guesses(forWord word: String, languageCode: String, limit: Int = 5) -> [String] {
        guard !word.isEmpty else { return [] }
        let range = NSRange(location: 0, length: word.utf16.count)
        guard let results = checker.guesses(forWordRange: range, in: word, language: languageCode) else {
            return []
        }
        return Array(results.prefix(limit))
    }

    /// Teaches the word to the system-wide user dictionary.
    static func learn(word: String) {
        guard word.count > 1 else { return }
        UITextChecker.learnWord(word)
    }

    static func unlearn(word: String) {
        UITextChecker.unlearnWord(word)
    }
}
