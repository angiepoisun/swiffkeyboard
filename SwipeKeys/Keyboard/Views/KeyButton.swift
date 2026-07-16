import UIKit

/// Pure-visual key. Touch handling lives in the parent (`TypingPadView` /
/// `BottomBarView`) so a whole row of keys can share one continuous touch
/// session — that's what makes glide typing possible.
final class KeyButton: UIView {
    let definition: KeyDefinition
    private let label = UILabel()
    private let iconView = UIImageView()

    var isKeyHighlighted = false {
        didSet { updateAppearance() }
    }

    init(definition: KeyDefinition) {
        self.definition = definition
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        layer.cornerRadius = 6
        clipsToBounds = false

        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.textColor = .label
        addSubview(label)

        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .label
        addSubview(iconView)

        [label, iconView].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.9),
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),
        ])

        updateAppearance()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// `displayText` is what's shown for `.char` keys (already cased by the
    /// caller according to shift state); `isCapsLocked` styles the shift key.
    func configure(displayText: String? = nil, isShiftActive: Bool = false, isCapsLocked: Bool = false) {
        label.text = nil
        iconView.image = nil

        switch definition {
        case .char(let base):
            label.text = displayText ?? base
            label.font = .systemFont(ofSize: 21, weight: .regular)
        case .shift:
            iconView.image = UIImage(systemName: isCapsLocked ? "capslock.fill" : (isShiftActive ? "shift.fill" : "shift"))
        case .backspace:
            iconView.image = UIImage(systemName: "delete.left")
        case .toSymbols1:
            label.text = "123"
            label.font = .systemFont(ofSize: 16, weight: .medium)
        case .toSymbols2:
            label.text = "#+="
            label.font = .systemFont(ofSize: 16, weight: .medium)
        case .toLetters:
            label.text = "ABC"
            label.font = .systemFont(ofSize: 16, weight: .medium)
        case .toggleEmoji:
            iconView.image = UIImage(systemName: "face.smiling")
        case .space:
            label.text = "space"
            label.font = .systemFont(ofSize: 14, weight: .regular)
            label.textColor = .secondaryLabel
        case .return:
            label.text = "return"
            label.font = .systemFont(ofSize: 15, weight: .medium)
        case .none:
            break
        }
    }

    /// Overrides the default label for this key (used by the spacebar to
    /// show "🇺🇸 space" / a live language-switch preview instead of the
    /// generic "space" text).
    func setCustomTitle(_ text: String, font: UIFont = .systemFont(ofSize: 14, weight: .regular), color: UIColor = .secondaryLabel) {
        iconView.image = nil
        label.text = text
        label.font = font
        label.textColor = color
    }

    private func updateAppearance() {
        backgroundColor = isKeyHighlighted ? KeyboardTheme.keyHighlight : keyBaseColor
    }

    private var keyBaseColor: UIColor {
        switch definition {
        case .char:
            return KeyboardTheme.letterKey
        default:
            return KeyboardTheme.controlKey
        }
    }
}

enum KeyboardTheme {
    static let background = UIColor.secondarySystemBackground
    static let letterKey = UIColor.systemBackground
    static let controlKey = UIColor.systemGray4
    static let keyHighlight = UIColor.systemGray2
    static let accent = UIColor.systemBlue
}
