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
    private lazy var wordDictionary = WordFrequencyDictionary(language: .englishUS)
    private lazy var pinyinDictionary = PinyinDictionary(language: .chineseSimplified)

    private var activeLanguage: SupportedLanguage { languages[activeLanguageIndex] }
    private var isPinyinMode: Bool { activeLanguage.inputMethod == .pinyin }

    /// Raw pinyin letters typed so far, never inserted into the document
    /// directly — only a chosen Hanzi candidate gets inserted. Custom
    /// keyboard extensions can't show real marked/preedit text in the host
    /// app's field (UITextDocumentProxy has no such API, unlike the system
    /// keyboard), so this buffer and its candidates live entirely in our
    /// own suggestion bar until committed.
    private var pinyinBuffer = ""

    private enum SuggestionContext {
        case none
        case typingWord(String)     // Latin tap-typing: prefix completions, replaceable
        case committedWord(String)  // Latin glide result already inserted (+ trailing space), replaceable
        case pinyinComposing        // Pinyin buffer in progress; nothing inserted yet
        case committedHanzi(String) // Pinyin glide result already inserted, replaceable
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
        languageLayout = LanguageLayout.layout(for: activeLanguage)
        reloadActiveDictionary()
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

        keyboardView.setDictionary(activeCandidateSource)
        keyboardView.setLanguages(languages, activeIndex: activeLanguageIndex)
    }

    private func preferredHeight(for size: CGSize) -> CGFloat {
        size.width > size.height ? 210 : 280
    }

    private var activeCandidateSource: any GlideCandidateSource {
        isPinyinMode ? pinyinDictionary : wordDictionary
    }

    private func reloadActiveDictionary() {
        switch activeLanguage.inputMethod {
        case .latin: wordDictionary.reload(language: activeLanguage)
        case .pinyin: pinyinDictionary.reload(language: activeLanguage)
        }
    }

    // MARK: - Page presentation

    private var swipeTypingEnabled: Bool {
        AppGroup.defaults.object(forKey: AppGroup.Key.swipeTypingEnabled) as? Bool ?? true
    }

    private func presentCurrentPage() {
        switch mode {
        case .letters:
            // Case doesn't mean anything for pinyin romanization; always show lowercase.
            let shifted = isPinyinMode ? false : isShifted
            let capsLocked = isPinyinMode ? false : isCapsLocked
            keyboardView.showTypingPage(languageLayout.page, mode: .letters, shifted: shifted, capsLocked: capsLocked, glideEnabled: swipeTypingEnabled)
        case .symbols1:
            keyboardView.showTypingPage(SymbolsLayout.page1, mode: .symbols1, shifted: false, capsLocked: false, glideEnabled: false)
        case .symbols2:
            keyboardView.showTypingPage(SymbolsLayout.page2, mode: .symbols2, shifted: false, capsLocked: false, glideEnabled: false)
        case .emoji:
            keyboardView.showEmojiPage()
        }
    }

    private func switchMode(to newMode: KeyboardMode) {
        if isPinyinMode, !pinyinBuffer.isEmpty {
            commitPinyinBuffer()
        }
        mode = newMode
        presentCurrentPage()
    }

    // MARK: - KeyboardViewActionDelegate

    func keyboardView(_ view: KeyboardView, didTapKey key: KeyDefinition) {
        switch key {
        case .char(let base):
            if isPinyinMode {
                pinyinBuffer += base.lowercased()
                suggestionContext = .pinyinComposing
                refreshPinyinSuggestions()
            } else {
                insertCharacter(base)
            }
        case .shift:
            isShifted.toggle()
            isCapsLocked = false
            keyboardView.updateShiftAppearance(shifted: isShifted, capsLocked: isCapsLocked)
        case .backspace:
            if isPinyinMode, !pinyinBuffer.isEmpty {
                pinyinBuffer.removeLast()
                if pinyinBuffer.isEmpty {
                    suggestionContext = .none
                    keyboardView.setSuggestions([])
                } else {
                    suggestionContext = .pinyinComposing
                    refreshPinyinSuggestions()
                }
            } else {
                textDocumentProxy.deleteBackward()
                suggestionContext = .typingWord(currentTypedWord())
                refreshSuggestions()
                updateAutoShiftState()
            }
        case .toSymbols1:
            switchMode(to: .symbols1)
        case .toSymbols2:
            switchMode(to: .symbols2)
        case .toLetters:
            switchMode(to: .letters)
        case .toggleEmoji:
            switchMode(to: .emoji)
        case .space:
            if isPinyinMode, !pinyinBuffer.isEmpty {
                commitPinyinBuffer()
            } else {
                commitPendingWordIfNeeded()
                textDocumentProxy.insertText(" ")
                suggestionContext = .none
                refreshSuggestions()
            }
            updateAutoShiftState()
        case .return:
            if isPinyinMode, !pinyinBuffer.isEmpty {
                commitPinyinBuffer()
            } else {
                commitPendingWordIfNeeded()
                textDocumentProxy.insertText("\n")
                suggestionContext = .none
                refreshSuggestions()
            }
            updateAutoShiftState()
        case .none:
            break
        }
    }

    func keyboardView(_ view: KeyboardView, didFinishGlide matchedKey: String, alternates alternateKeys: [String]) {
        if isPinyinMode {
            pinyinBuffer = ""
            let primaryCandidates = pinyinDictionary.hanziCandidates(forExactPinyin: matchedKey)
            guard let topHanzi = primaryCandidates.first else { return }
            textDocumentProxy.insertText(topHanzi)

            var suggestions = primaryCandidates
            for altKey in alternateKeys {
                if let altTop = pinyinDictionary.hanziCandidates(forExactPinyin: altKey).first,
                   !suggestions.contains(altTop) {
                    suggestions.append(altTop)
                }
            }
            suggestionContext = .committedHanzi(topHanzi)
            keyboardView.setSuggestions(suggestions)
        } else {
            let candidates = wordDictionary.applyCorrections(to: [matchedKey] + alternateKeys)
            let top = candidates[0]
            let cased = applyCurrentCase(to: top)
            textDocumentProxy.insertText(cased + " ")
            wordDictionary.learn(word: top)
            suggestionContext = .committedWord(top)
            keyboardView.setSuggestions(candidates)
            if isShifted, !isCapsLocked {
                isShifted = false
                keyboardView.updateShiftAppearance(shifted: isShifted, capsLocked: isCapsLocked)
            }
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

    func keyboardView(_ view: KeyboardView, didSelectSuggestion selectedText: String) {
        switch suggestionContext {
        case .typingWord(let current):
            deleteBackward(count: current.count)
            let cased = applyCurrentCase(to: selectedText)
            textDocumentProxy.insertText(cased + " ")
            wordDictionary.learn(word: selectedText)
        case .committedWord(let current):
            deleteBackward(count: current.count + 1) // + trailing space
            let cased = applyCurrentCase(to: selectedText)
            textDocumentProxy.insertText(cased + " ")
            wordDictionary.learn(word: selectedText)
            wordDictionary.recordCorrection(from: current, to: selectedText)
        case .committedHanzi(let current):
            deleteBackward(count: current.count) // no trailing space to account for
            textDocumentProxy.insertText(selectedText)
        case .pinyinComposing:
            // Nothing has touched the document yet; just commit the pick.
            textDocumentProxy.insertText(selectedText)
            pinyinBuffer = ""
        case .none:
            textDocumentProxy.insertText(selectedText + " ")
            wordDictionary.learn(word: selectedText)
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
            wordDictionary.learn(word: word)
        }
    }

    /// Inserts the top candidate for the current pinyin buffer (or the raw
    /// letters, if nothing matched, so typing is never silently dropped).
    private func commitPinyinBuffer() {
        guard !pinyinBuffer.isEmpty else { return }
        let candidates = pinyinDictionary.hanziCandidates(forExactPinyin: pinyinBuffer)
        textDocumentProxy.insertText(candidates.first ?? pinyinBuffer)
        pinyinBuffer = ""
        suggestionContext = .none
        keyboardView.setSuggestions([])
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
        keyboardView.setSuggestions(wordDictionary.completions(forPrefix: word))
    }

    private func refreshPinyinSuggestions() {
        guard mode == .letters, !pinyinBuffer.isEmpty else {
            keyboardView.setSuggestions([])
            return
        }
        keyboardView.setSuggestions(pinyinDictionary.candidates(forPrefix: pinyinBuffer))
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
        languageLayout = LanguageLayout.layout(for: language)
        pinyinBuffer = ""
        mode = .letters
        suggestionContext = .none

        reloadActiveDictionary()
        presentCurrentPage()
        keyboardView.setDictionary(activeCandidateSource)
        keyboardView.setLanguages(languages, activeIndex: activeLanguageIndex)
        keyboardView.setSuggestions([])
        if showToast {
            keyboardView.showLanguageToast(language)
        }
    }
}
