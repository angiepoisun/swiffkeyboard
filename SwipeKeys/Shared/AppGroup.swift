import Foundation

/// Storage shared between the container app and the keyboard extension.
enum AppGroup {
    static let suiteName = "group.com.angieng.swipekeys"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    enum Key {
        static let enabledLanguageIDs = "enabledLanguageIDs"
        static let activeLanguageID = "activeLanguageID"
        static let learnedWords = "learnedWords"
        static let glideCorrections = "glideCorrections"
        static let swipeTypingEnabled = "swipeTypingEnabled"
        static let autoCapitalize = "autoCapitalize"
        static let recentEmoji = "recentEmoji"
    }
}

/// The languages/layouts SwipeKeys ships with. Both the app (for the settings
/// screen) and the keyboard extension (for the actual layout + dictionary)
/// share this list so they never drift apart.
enum SupportedLanguage: String, CaseIterable, Identifiable, Codable {
    case englishUS = "en-US"
    case spanish = "es-ES"
    case french = "fr-FR"
    case german = "de-DE"
    case chineseSimplified = "zh-Hans"
    case chineseTraditional = "zh-Hant"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .englishUS: return "English"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .chineseSimplified: return "简体中文"
        case .chineseTraditional: return "繁體中文"
        }
    }

    var flag: String {
        switch self {
        case .englishUS: return "🇺🇸"
        case .spanish: return "🇪🇸"
        case .french: return "🇫🇷"
        case .german: return "🇩🇪"
        case .chineseSimplified: return "🇨🇳"
        case .chineseTraditional: return "🇹🇼"
        }
    }

    var wordListResourceName: String {
        switch self {
        case .englishUS: return "en"
        case .spanish: return "es"
        case .french: return "fr"
        case .german: return "de"
        case .chineseSimplified: return "zh-Hans"
        case .chineseTraditional: return "zh-Hant"
        }
    }

    /// How keys typed on the QWERTY layout turn into inserted text. Latin
    /// languages insert each tapped/glided letter (or word) directly.
    /// Pinyin languages type a romanization that never touches the document
    /// on its own — it composes in a local buffer and only a chosen Hanzi
    /// candidate gets inserted, the same constraint every third-party
    /// Chinese iOS keyboard works under (UITextDocumentProxy has no marked
    /// / preedit text support, unlike the system keyboard).
    var inputMethod: KeyboardInputMethod {
        switch self {
        case .englishUS, .spanish, .french, .german: return .latin
        case .chineseSimplified, .chineseTraditional: return .pinyin
        }
    }
}

enum KeyboardInputMethod {
    case latin
    case pinyin
}

/// Reads/writes the ordered list of languages the user has enabled for
/// spacebar-swipe cycling, plus which one is currently active.
enum LanguageSettings {
    static func enabledLanguages() -> [SupportedLanguage] {
        let defaults = AppGroup.defaults
        guard let ids = defaults.array(forKey: AppGroup.Key.enabledLanguageIDs) as? [String],
              !ids.isEmpty else {
            return [.englishUS]
        }
        let langs = ids.compactMap(SupportedLanguage.init(rawValue:))
        return langs.isEmpty ? [.englishUS] : langs
    }

    static func setEnabledLanguages(_ languages: [SupportedLanguage]) {
        let defaults = AppGroup.defaults
        let ids = languages.isEmpty ? [SupportedLanguage.englishUS.rawValue] : languages.map(\.rawValue)
        defaults.set(ids, forKey: AppGroup.Key.enabledLanguageIDs)
        if let active = activeLanguage(), !languages.contains(active) {
            setActiveLanguage(languages.first ?? .englishUS)
        }
    }

    static func activeLanguage() -> SupportedLanguage? {
        guard let id = AppGroup.defaults.string(forKey: AppGroup.Key.activeLanguageID) else {
            return enabledLanguages().first
        }
        return SupportedLanguage(rawValue: id) ?? enabledLanguages().first
    }

    static func setActiveLanguage(_ language: SupportedLanguage) {
        AppGroup.defaults.set(language.rawValue, forKey: AppGroup.Key.activeLanguageID)
    }
}
