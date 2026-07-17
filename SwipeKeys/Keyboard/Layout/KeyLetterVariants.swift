import Foundation

/// Long-press accent/alternate-character options per base letter, matching
/// the standard iOS keyboard convention (long-press "e" for é è ê ë…).
/// Scoped per language since which variants make sense differs — German's
/// ä/ö/ü are already dedicated keys on that layout so aren't duplicated
/// here, and Pinyin input intentionally has none: it's toneless
/// romanization matched against a toneless dictionary, so inserting a
/// tone-marked vowel would just fail to match anything in it.
enum KeyLetterVariants {
    static func variants(for base: String, language: SupportedLanguage) -> [String] {
        guard language.inputMethod == .latin else { return [] }
        switch language {
        case .englishUS: return englishVariants[base] ?? []
        case .spanish: return spanishVariants[base] ?? []
        case .french: return frenchVariants[base] ?? []
        case .german: return germanVariants[base] ?? []
        case .chineseSimplified, .chineseTraditional: return []
        }
    }

    private static let englishVariants: [String: [String]] = [
        "a": ["à", "á", "â", "ä", "æ", "ã", "å", "ā"],
        "e": ["è", "é", "ê", "ë", "ē", "ė", "ę"],
        "i": ["ì", "í", "î", "ï", "ī", "į"],
        "o": ["ò", "ó", "ô", "ö", "õ", "ø", "ō"],
        "u": ["ù", "ú", "û", "ü", "ū"],
        "s": ["ß", "ś", "š"],
        "c": ["ç", "ć", "č"],
        "n": ["ñ", "ń"],
        "y": ["ÿ"],
    ]

    private static let spanishVariants: [String: [String]] = [
        "a": ["á"],
        "e": ["é"],
        "i": ["í"],
        "o": ["ó"],
        "u": ["ú", "ü"],
    ]

    private static let frenchVariants: [String: [String]] = [
        "a": ["à", "â", "æ"],
        "e": ["é", "è", "ê", "ë"],
        "i": ["î", "ï"],
        "o": ["ô", "œ"],
        "u": ["ù", "û", "ü"],
        "c": ["ç"],
        "y": ["ÿ"],
    ]

    private static let germanVariants: [String: [String]] = [
        "s": ["ß"],
    ]
}
