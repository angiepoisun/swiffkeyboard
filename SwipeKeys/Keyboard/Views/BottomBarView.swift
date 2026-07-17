import UIKit

protocol BottomBarDelegate: AnyObject {
    func bottomBar(_ bar: BottomBarView, didTapKey key: KeyDefinition)
    func bottomBar(_ bar: BottomBarView, didCommitLanguageSwitch language: SupportedLanguage)
}

/// The row that replaces the traditional "123 / emoji / space / globe /
/// return" bar. There is no globe key: swiping left or right anywhere on
/// the spacebar cycles the keyboard's input language, previewing the
/// target language as you drag and committing it on release. That's the
/// space the globe key used to occupy, freed up.
final class BottomBarView: UIView {
    weak var delegate: BottomBarDelegate?

    var enabledLanguages: [SupportedLanguage] = [.englishUS] {
        didSet { updateIdleSpaceLabel() }
    }
    var activeLanguageIndex: Int = 0 {
        didSet { updateIdleSpaceLabel() }
    }

    private var modeButton = KeyButton(definition: .toSymbols1)
    private var emojiButton = KeyButton(definition: .toggleEmoji)
    private var spaceButton = KeyButton(definition: .space)
    private var returnButton = KeyButton(definition: .return)

    private var currentMode: KeyboardMode = .letters
    private var touchStartPoint: CGPoint = .zero
    private var isDraggingSpace = false
    private var didCommitSwitch = false

    private let commitThreshold: CGFloat = 42

    override init(frame: CGRect) {
        super.init(frame: frame)
        modeButton.configure()
        emojiButton.configure()
        returnButton.configure()
        [modeButton, emojiButton, spaceButton, returnButton].forEach { addSubview($0) }
        updateIdleSpaceLabel()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setMode(_ mode: KeyboardMode) {
        currentMode = mode
        modeButton = replace(modeButton, with: mode == .letters ? .toSymbols1 : .toLetters)
        emojiButton.configure()
        setNeedsLayout()
    }

    private func replace(_ old: KeyButton, with definition: KeyDefinition) -> KeyButton {
        guard old.definition != definition else { return old }
        old.removeFromSuperview()
        let button = KeyButton(definition: definition)
        button.configure()
        addSubview(button)
        setNeedsLayout()
        return button
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let inset: CGFloat = 3
        let height = bounds.height - inset * 2
        let modeWidth: CGFloat = bounds.width * 0.14
        let emojiWidth: CGFloat = bounds.width * 0.12
        let returnWidth: CGFloat = bounds.width * 0.20
        let spaceWidth = bounds.width - modeWidth - emojiWidth - returnWidth

        var x: CGFloat = 0
        modeButton.frame = CGRect(x: x + inset, y: inset, width: modeWidth - inset * 2, height: height)
        x += modeWidth
        emojiButton.frame = CGRect(x: x + inset, y: inset, width: emojiWidth - inset * 2, height: height)
        x += emojiWidth
        spaceButton.frame = CGRect(x: x + inset, y: inset, width: spaceWidth - inset * 2, height: height)
        x += spaceWidth
        returnButton.frame = CGRect(x: x + inset, y: inset, width: returnWidth - inset * 2, height: height)
    }

    private func updateIdleSpaceLabel() {
        guard let language = enabledLanguages[safe: activeLanguageIndex] else {
            spaceButton.setCustomTitle("")
            return
        }
        spaceButton.setCustomTitle(idleLabel(for: language), font: .systemFont(ofSize: 15, weight: .regular))
    }

    /// Wrapped in chevrons only when there's actually somewhere to swipe
    /// to — with a single language enabled, swiping the spacebar is a
    /// no-op, so there's nothing to hint at.
    private func idleLabel(for language: SupportedLanguage) -> String {
        enabledLanguages.count > 1 ? "‹  \(language.displayName)  ›" : language.displayName
    }

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)
        touchStartPoint = point
        isDraggingSpace = false
        didCommitSwitch = false

        for button in [modeButton, emojiButton, spaceButton, returnButton] {
            button.isKeyHighlighted = button.frame.contains(point)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, spaceButton.frame.contains(touchStartPoint) else { return }
        let point = touch.location(in: self)
        let dx = point.x - touchStartPoint.x

        guard abs(dx) > 10, enabledLanguages.count > 1 else { return }
        isDraggingSpace = true
        spaceButton.isKeyHighlighted = false

        let previewIndex = targetIndex(forDelta: dx)
        let previewLanguage = enabledLanguages[previewIndex]
        let progress = min(abs(dx) / commitThreshold, 1.0)
        spaceButton.setCustomTitle(
            previewLanguage.displayName,
            font: .systemFont(ofSize: 14 + 2 * progress, weight: progress >= 1 ? .semibold : .regular),
            color: progress >= 1 ? KeyboardTheme.accent : .secondaryLabel
        )
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        defer {
            [modeButton, emojiButton, spaceButton, returnButton].forEach { $0.isKeyHighlighted = false }
        }

        guard let touch = touches.first else { return }
        let point = touch.location(in: self)

        if isDraggingSpace {
            let dx = point.x - touchStartPoint.x
            if abs(dx) >= commitThreshold, enabledLanguages.count > 1 {
                let newIndex = targetIndex(forDelta: dx)
                activeLanguageIndex = newIndex
                didCommitSwitch = true
                delegate?.bottomBar(self, didCommitLanguageSwitch: enabledLanguages[newIndex])
            }
            updateIdleSpaceLabel()
            isDraggingSpace = false
            return
        }

        if modeButton.frame.contains(point) {
            delegate?.bottomBar(self, didTapKey: modeButton.definition)
        } else if emojiButton.frame.contains(point) {
            delegate?.bottomBar(self, didTapKey: .toggleEmoji)
        } else if spaceButton.frame.contains(point) {
            delegate?.bottomBar(self, didTapKey: .space)
        } else if returnButton.frame.contains(point) {
            delegate?.bottomBar(self, didTapKey: .return)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        [modeButton, emojiButton, spaceButton, returnButton].forEach { $0.isKeyHighlighted = false }
        isDraggingSpace = false
        updateIdleSpaceLabel()
    }

    private func targetIndex(forDelta dx: CGFloat) -> Int {
        let count = enabledLanguages.count
        let step = dx > 0 ? 1 : -1
        return ((activeLanguageIndex + step) % count + count) % count
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
