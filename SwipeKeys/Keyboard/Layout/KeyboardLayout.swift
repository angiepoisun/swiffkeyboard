import Foundation

/// One physical key on the letters/symbols keyboard.
enum KeyDefinition: Equatable {
    case char(String)
    case shift
    case backspace
    case toSymbols1
    case toSymbols2
    case toLetters
    case toggleEmoji
    case space
    case `return`
    case none

    /// Whether this key participates in glide-typing paths.
    var isGlideable: Bool {
        if case .char = self { return true }
        return false
    }
}

/// A full keyboard page: rows of keys. The bottom row (mode switch / space /
/// return) is added separately by the view so every page shares one control
/// bar.
struct KeyboardPage {
    let rows: [[KeyDefinition]]
}

/// Per-language layout: which physical arrangement (QWERTY/AZERTY/QWERTZ)
/// and any extra letters (ñ, ü, ö, ä, ç…) the language adds.
struct LanguageLayout {
    let language: SupportedLanguage
    let letterRows: [[String]] // lowercase base rows, shift is applied at render time

    static let all: [SupportedLanguage: LanguageLayout] = [
        .englishUS: LanguageLayout(language: .englishUS, letterRows: [
            ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
            ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
            ["z", "x", "c", "v", "b", "n", "m"],
        ]),
        .spanish: LanguageLayout(language: .spanish, letterRows: [
            ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
            ["a", "s", "d", "f", "g", "h", "j", "k", "l", "ñ"],
            ["z", "x", "c", "v", "b", "n", "m"],
        ]),
        .french: LanguageLayout(language: .french, letterRows: [
            ["a", "z", "e", "r", "t", "y", "u", "i", "o", "p"],
            ["q", "s", "d", "f", "g", "h", "j", "k", "l", "m"],
            ["w", "x", "c", "v", "b", "n"],
        ]),
        .german: LanguageLayout(language: .german, letterRows: [
            ["q", "w", "e", "r", "t", "z", "u", "i", "o", "p", "ü"],
            ["a", "s", "d", "f", "g", "h", "j", "k", "l", "ö", "ä"],
            ["y", "x", "c", "v", "b", "n", "m"],
        ]),
        // Pinyin input uses the plain QWERTY layout to spell romanized
        // syllables (e.g. "nihao"); the candidate bar turns that into Hanzi.
        .chineseSimplified: LanguageLayout(language: .chineseSimplified, letterRows: [
            ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
            ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
            ["z", "x", "c", "v", "b", "n", "m"],
        ]),
        .chineseTraditional: LanguageLayout(language: .chineseTraditional, letterRows: [
            ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
            ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
            ["z", "x", "c", "v", "b", "n", "m"],
        ]),
    ]

    static func layout(for language: SupportedLanguage) -> LanguageLayout {
        all[language] ?? all[.englishUS]!
    }

    /// The digit row shown above the letters, always present per SwipeKeys'
    /// design (no separate "show number row" toggle needed).
    static let numberRow: [String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]

    /// Always lowercase, canonical key identities. Casing for display and
    /// for inserted text is applied separately at shift-state time (see
    /// `TypingPadView.applyState` and `KeyboardViewController`) — a key's
    /// identity should never depend on whether shift happened to be down
    /// when the page was built.
    var page: KeyboardPage {
        let numbers: [KeyDefinition] = LanguageLayout.numberRow.map { .char($0) }
        let row1: [KeyDefinition] = letterRows[0].map { .char($0) }
        let row2: [KeyDefinition] = letterRows[1].map { .char($0) }
        var row3: [KeyDefinition] = [.shift]
        row3.append(contentsOf: letterRows[2].map { .char($0) })
        row3.append(.backspace)
        return KeyboardPage(rows: [numbers, row1, row2, row3])
    }
}

enum SymbolsLayout {
    static let page1 = KeyboardPage(rows: [
        LanguageLayout.numberRow.map { .char($0) },
        ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""].map { .char($0) },
        [KeyDefinition.toSymbols2] + [".", ",", "?", "!", "'"].map { .char($0) } + [.backspace],
    ])

    static let page2 = KeyboardPage(rows: [
        LanguageLayout.numberRow.map { .char($0) },
        ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="].map { .char($0) },
        [KeyDefinition.toSymbols1] + ["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"].map { .char($0) } + [.backspace],
    ])
}

enum KeyboardMode {
    case letters
    case symbols1
    case symbols2
    case emoji
}
