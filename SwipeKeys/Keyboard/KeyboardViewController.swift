import UIKit

final class KeyboardViewController: UIInputViewController, KeyboardViewActionDelegate {
    private var keyboardView: KeyboardView!
    private var heightConstraint: NSLayoutConstraint?

    private var mode: KeyboardMode = .letters
    private var isShifted = true
    private var isCapsLocked = false

    private var languages: [SupportedLanguage] = [.englishUS]
    private var activeLanguageIndex = 0
    private var languageLayout = LanguageLayout.layout(for: .englishUS)
    private lazy var dictionary = WordFrequencyDictionary(language: .englishUS)

    private enum SuggestionContext {
        case none
        case typingWord(String)
        case committedWord(String)
    }
    private var suggestionContext: SuggestionContext = .none

    override func viewDidLoad() {
        super.viewDidLoad()
        loadLanguageState()
        setupKeyboardView()
        presentCurrentPage()
        updateAutoShiftState()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.heightConstraint?.constant = self?.preferredHeight(for: size) ?? 280
        })
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        updateAutoShiftState()
    }

    // MARK: - Setup

    private func loadLanguageState() {
        languages = LanguageSettings.enabledLanguages()
        let active = LanguageSettings.activeLanguage() ?? languages.first ?? .englishUS
        activeLanguageIndex = languages.firstIndex(of: active) ?? 0
        languageLayout = LanguageLayout.layout(for: languages[activeLanguageIndex])
        dictionary.reload(language: languages[activeLanguageIndex])
    }

    private func setupKeyboardView() {
        let keyboardView = KeyboardView(frame: .zero)
        keyboardView.actionDelegate = self
        keyboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(keyboardView)
        NSLayoutConstraint.activate([
            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboardView.topAnchor.constraint(equalTo: view.topAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        self.keyboardView = keyboardView

        let heightConstraint = view.heightAnchor.constraint(equalToConstant: preferredHeight(for: UIScreen.main.bounds.size))
        heightConstraint.priority = .defaultHigh
        heightConstraint.isActive = true
        self.heightConstraint = heightConstraint

        keyboardView.setDictionary(dictionary)
        keyboardView.setLanguages(languages, activeIndex: activeLanguageIndex)
    }

    private func preferredHeight(for size: CGSize) -> CGFloat {
        size.width > size.height ? 210 : 280
    }

    // MARK: - Page presentation

    private var swipeTypingEnabled: Bool {
        AppGroup.defaults.object(forKey: AppGroup.Key.swipeTypingEnabled) as? Bool ?? true
    }

    private func presentCurrentPage() {
        switch mode {
        case .letters:
            keyboardView.showTypingPage(languageLayout.page, mode: .letters, shifted: isShifted, capsLocked: isCapsLocked, glideEnabled: swipeTypingEnabled)
        case .symbols1:
            keyboardView.showTypingPage(SymbolsLayout.page1, mode: .symbols1, shifted: false, capsLocked: false, glideEnabled: false)
        case .symbols2:
            keyboardView.showTypingPage(SymbolsLayout.page2, mode: .symbols2, shifted: false, capsLocked: false, glideEnabled: false)
        case .emoji:
            keyboardView.showEmojiPage()
        }
    }

    // MARK: - KeyboardViewActionDelegate

    func keyboardView(_ view: KeyboardView, didTapKey key: KeyDefinition) {
        switch key {
        case .char(let base):
            insertCharacter(base)
        case .shift:
            isShifted.toggle()
            isCapsLocked = false
            keyboardView.updateShiftAppearance(shifted: isShifted, capsLocked: isCapsLocked)
        case .backspace:
            textDocumentProxy.deleteBackward()
            suggestionContext = .typingWord(currentTypedWord())
            refreshSuggestions()
            updateAutoShiftState()
        case .toSymbols1:
            mode = .symbols1
            presentCurrentPage()
        case .toSymbols2:
            mode = .symbols2
            presentCurrentPage()
        case .toLetters:
            mode = .letters
            presentCurrentPage()
        case .toggleEmoji:
            mode = .emoji
            presentCurrentPage()
        case .space:
            commitPendingWordIfNeeded()
            textDocumentProxy.insertText(" ")
            suggestionContext = .none
            refreshSuggestions()
            updateAutoShiftState()
        case .return:
            commitPendingWordIfNeeded()
            textDocumentProxy.insertText("\n")
            suggestionContext = .none
            refreshSuggestions()
            updateAutoShiftState()
        case .none:
            break
        }
    }

    func keyboardView(_ view: KeyboardView, didFinishGlide word: String, alternates: [String]) {
        let cased = applyCurrentCase(to: word)
        textDocumentProxy.insertText(cased + " ")
        dictionary.learn(word: word)
        suggestionContext = .committedWord(word)
        keyboardView.setSuggestions(([word] + alternates).map { $0 })
        if isShifted, !isCapsLocked {
            isShifted = false
            keyboardView.updateShiftAppearance(shifted: isShifted, capsLocked: isCapsLocked)
        }
        updateAutoShiftState()
    }

    func keyboardViewDidDoubleTapShift(_ view: KeyboardView) {
        isCapsLocked.toggle()
        isShifted = isCapsLocked
        keyboardView.updateShiftAppearance(shifted: isShifted, capsLocked: isCapsLocked)
    }

    func keyboardView(_ view: KeyboardView, didCommitLanguageSwitch language: SupportedLanguage) {
        setActiveLanguage(language, showToast: true)
    }

    func keyboardView(_ view: KeyboardView, didSelectSuggestion word: String) {
        switch suggestionContext {
        case .typingWord(let current):
            deleteBackward(count: current.count)
            let cased = applyCurrentCase(to: word)
            textDocumentProxy.insertText(cased + " ")
            dictionary.learn(word: word)
        case .committedWord(let current):
            deleteBackward(count: current.count + 1) // + trailing space
            let cased = applyCurrentCase(to: word)
            textDocumentProxy.insertText(cased + " ")
            dictionary.learn(word: word)
        case .none:
            textDocumentProxy.insertText(word + " ")
            dictionary.learn(word: word)
        }
        suggestionContext = .none
        keyboardView.setSuggestions([])
        updateAutoShiftState()
    }

    func keyboardView(_ view: KeyboardView, didSelectEmoji emoji: String) {
        textDocumentProxy.insertText(emoji)
    }

    // MARK: - Typing helpers

    private func insertCharacter(_ base: String) {
        let text = (isShifted || isCapsLocked) ? base.uppercased() : base
        textDocumentProxy.insertText(text)
        if isShifted, !isCapsLocked {
            isShifted = false
            keyboardView.updateShiftAppearance(shifted: isShifted, capsLocked: isCapsLocked)
        }
        suggestionContext = .typingWord(currentTypedWord())
        refreshSuggestions()
    }

    private func applyCurrentCase(to word: String) -> String {
        if isCapsLocked { return word.uppercased() }
        if isShifted { return word.prefix(1).uppercased() + word.dropFirst() }
        return word
    }

    private func commitPendingWordIfNeeded() {
        if case .typingWord(let word) = suggestionContext, word.count > 1 {
            dictionary.learn(word: word)
        }
    }

    private func deleteBackward(count: Int) {
        for _ in 0..<count { textDocumentProxy.deleteBackward() }
    }

    private func currentTypedWord() -> String {
        guard let context = textDocumentProxy.documentContextBeforeInput else { return "" }
        var word = ""
        for char in context.reversed() {
            if char.isLetter {
                word.append(char)
            } else {
                break
            }
        }
        return String(word.reversed())
    }

    private func refreshSuggestions() {
        guard mode == .letters, case .typingWord(let word) = suggestionContext, !word.isEmpty else {
            keyboardView.setSuggestions([])
            return
        }
        keyboardView.setSuggestions(dictionary.completions(forPrefix: word))
    }

    private func updateAutoShiftState() {
        guard !isCapsLocked else { return }
        let autoCapitalizeSetting = AppGroup.defaults.object(forKey: AppGroup.Key.autoCapitalize) as? Bool ?? true
        guard autoCapitalizeSetting else { return }
        let shouldCapitalize = shouldAutoCapitalize()
        if shouldCapitalize != isShifted {
            isShifted = shouldCapitalize
            keyboardView.updateShiftAppearance(shifted: isShifted, capsLocked: isCapsLocked)
        }
    }

    private func shouldAutoCapitalize() -> Bool {
        guard let context = textDocumentProxy.documentContextBeforeInput else { return true }
        let trimmedTrailing = String(context.reversed().drop(while: { $0 == " " || $0 == "\n" || $0 == "\t" }).reversed())
        if trimmedTrailing.isEmpty { return true }
        guard context.count != trimmedTrailing.count else { return false } // no trailing whitespace: mid-word
        if let last = trimmedTrailing.last, ".!?".contains(last) { return true }
        return false
    }

    // MARK: - Language switching

    private func setActiveLanguage(_ language: SupportedLanguage, showToast: Bool) {
        guard let index = languages.firstIndex(of: language) else { return }
        activeLanguageIndex = index
        LanguageSettings.setActiveLanguage(language)
        dictionary.reload(language: language)
        languageLayout = LanguageLayout.layout(for: language)
        mode = .letters
        suggestionContext = .none
        presentCurrentPage()
        keyboardView.setDictionary(dictionary)
        keyboardView.setLanguages(languages, activeIndex: activeLanguageIndex)
        keyboardView.setSuggestions([])
        if showToast {
            keyboardView.showLanguageToast(language)
        }
    }
}
