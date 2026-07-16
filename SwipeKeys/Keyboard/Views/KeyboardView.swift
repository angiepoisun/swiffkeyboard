import UIKit

protocol KeyboardViewActionDelegate: AnyObject {
    func keyboardView(_ view: KeyboardView, didTapKey key: KeyDefinition)
    func keyboardView(_ view: KeyboardView, didFinishGlide word: String, alternates: [String])
    func keyboardViewDidDoubleTapShift(_ view: KeyboardView)
    func keyboardView(_ view: KeyboardView, didCommitLanguageSwitch language: SupportedLanguage)
    func keyboardView(_ view: KeyboardView, didSelectSuggestion word: String)
    func keyboardView(_ view: KeyboardView, didSelectEmoji emoji: String)
}

/// Composes the suggestion strip, the typing pad (numbers + letters or
/// symbols, with glide typing), the bottom control bar (mode toggle, emoji
/// toggle, language-swiping spacebar, return), and the emoji pad — and
/// forwards every user action up to `KeyboardViewController` through
/// `KeyboardViewActionDelegate`. This view owns layout only; typing state
/// (shift, active page, active language) lives in the controller.
final class KeyboardView: UIView, TypingPadDelegate, BottomBarDelegate, SuggestionBarDelegate, EmojiPadDelegate {
    weak var actionDelegate: KeyboardViewActionDelegate?

    private let suggestionBar = SuggestionBarView()
    private let typingPad = TypingPadView()
    private let bottomBar = BottomBarView()
    private let emojiPad = EmojiPadView()
    private let toast = LanguageToastView()

    private var showingEmoji = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = KeyboardTheme.background

        typingPad.delegate = self
        bottomBar.delegate = self
        suggestionBar.delegate = self
        emojiPad.delegate = self

        addSubview(suggestionBar)
        addSubview(typingPad)
        addSubview(bottomBar)
        addSubview(emojiPad)
        emojiPad.isHidden = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Configuration (driven by the controller)

    func setDictionary(_ dictionary: WordFrequencyDictionary) {
        typingPad.dictionary = dictionary
    }

    func setLanguages(_ languages: [SupportedLanguage], activeIndex: Int) {
        bottomBar.enabledLanguages = languages
        bottomBar.activeLanguageIndex = activeIndex
    }

    func setSuggestions(_ words: [String]) {
        suggestionBar.setSuggestions(words)
    }

    func showLanguageToast(_ language: SupportedLanguage) {
        toast.show(language: language, in: self)
    }

    func updateShiftAppearance(shifted: Bool, capsLocked: Bool) {
        typingPad.updateShiftAppearance(shifted: shifted, capsLocked: capsLocked)
    }

    func showTypingPage(_ page: KeyboardPage, mode: KeyboardMode, shifted: Bool, capsLocked: Bool, glideEnabled: Bool) {
        showingEmoji = false
        typingPad.setPage(page, shifted: shifted, capsLocked: capsLocked, glideEnabled: glideEnabled)
        bottomBar.setMode(mode)
        typingPad.isHidden = false
        bottomBar.isHidden = false
        emojiPad.isHidden = true
        setNeedsLayout()
    }

    func showEmojiPage() {
        showingEmoji = true
        typingPad.isHidden = true
        bottomBar.isHidden = true
        emojiPad.isHidden = false
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let suggestionHeight: CGFloat = 40
        suggestionBar.frame = CGRect(x: 0, y: 0, width: bounds.width, height: suggestionHeight)
        let remaining = bounds.height - suggestionHeight

        if showingEmoji {
            emojiPad.frame = CGRect(x: 0, y: suggestionHeight, width: bounds.width, height: remaining)
        } else {
            let bottomBarHeight = remaining / 5
            typingPad.frame = CGRect(x: 0, y: suggestionHeight, width: bounds.width, height: remaining - bottomBarHeight)
            bottomBar.frame = CGRect(x: 0, y: suggestionHeight + remaining - bottomBarHeight, width: bounds.width, height: bottomBarHeight)
        }
    }

    // MARK: - TypingPadDelegate

    func typingPad(_ pad: TypingPadView, didTapKey key: KeyDefinition) {
        actionDelegate?.keyboardView(self, didTapKey: key)
    }

    func typingPad(_ pad: TypingPadView, didFinishGlide word: String, alternates: [String]) {
        actionDelegate?.keyboardView(self, didFinishGlide: word, alternates: alternates)
    }

    func typingPadDidDoubleTapShift(_ pad: TypingPadView) {
        actionDelegate?.keyboardViewDidDoubleTapShift(self)
    }

    // MARK: - BottomBarDelegate

    func bottomBar(_ bar: BottomBarView, didTapKey key: KeyDefinition) {
        actionDelegate?.keyboardView(self, didTapKey: key)
    }

    func bottomBar(_ bar: BottomBarView, didCommitLanguageSwitch language: SupportedLanguage) {
        actionDelegate?.keyboardView(self, didCommitLanguageSwitch: language)
    }

    // MARK: - SuggestionBarDelegate

    func suggestionBar(_ bar: SuggestionBarView, didSelect word: String) {
        actionDelegate?.keyboardView(self, didSelectSuggestion: word)
    }

    // MARK: - EmojiPadDelegate

    func emojiPad(_ pad: EmojiPadView, didSelect emoji: String) {
        actionDelegate?.keyboardView(self, didSelectEmoji: emoji)
    }

    func emojiPadDidTapBackspace(_ pad: EmojiPadView) {
        actionDelegate?.keyboardView(self, didTapKey: .backspace)
    }

    func emojiPadDidTapABC(_ pad: EmojiPadView) {
        actionDelegate?.keyboardView(self, didTapKey: .toLetters)
    }
}
