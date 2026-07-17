import UIKit

protocol SuggestionBarDelegate: AnyObject {
    func suggestionBar(_ bar: SuggestionBarView, didSelect word: String)
}

/// Strip above the keys showing the top glide/tap candidate plus
/// alternates. Tapping one replaces whatever was just inserted.
///
/// Also doubles as the only place composing pinyin is visible at all:
/// a custom keyboard extension can't show real marked/preedit text in the
/// host app's text field (`UITextDocumentProxy` has no such API), so the
/// raw pinyin buffer is shown here, to the left of the Hanzi candidates,
/// until a candidate is picked.
final class SuggestionBarView: UIView {
    weak var delegate: SuggestionBarDelegate?

    private var buttons: [UIButton] = []
    private var words: [String] = []
    private let pinyinLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = KeyboardTheme.background

        pinyinLabel.font = .systemFont(ofSize: 17, weight: .regular)
        pinyinLabel.textColor = .label
        pinyinLabel.textAlignment = .left
        pinyinLabel.isUserInteractionEnabled = false
        addSubview(pinyinLabel)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// The pinyin typed so far while composing, or "" once committed/idle.
    func setPinyinBuffer(_ text: String) {
        pinyinLabel.text = text.isEmpty ? nil : text
        setNeedsLayout()
    }

    func setSuggestions(_ words: [String]) {
        self.words = words
        buttons.forEach { $0.removeFromSuperview() }
        buttons = words.enumerated().map { index, word in
            let button = UIButton(type: .system)
            var config = UIButton.Configuration.plain()
            config.title = word
            config.baseForegroundColor = index == 0 ? .label : .secondaryLabel
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = .systemFont(ofSize: 16, weight: index == 0 ? .semibold : .regular)
                return outgoing
            }
            button.configuration = config
            button.tag = index
            button.addTarget(self, action: #selector(tapped(_:)), for: .touchUpInside)
            addSubview(button)
            return button
        }
        setNeedsLayout()
    }

    @objc private func tapped(_ sender: UIButton) {
        guard words.indices.contains(sender.tag) else { return }
        delegate?.suggestionBar(self, didSelect: words[sender.tag])
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        var leadingInset: CGFloat = 0
        if let text = pinyinLabel.text, !text.isEmpty {
            let naturalWidth = pinyinLabel.sizeThatFits(CGSize(width: .greatestFiniteMagnitude, height: bounds.height)).width
            let width = min(bounds.width * 0.4, naturalWidth + 16)
            pinyinLabel.frame = CGRect(x: 10, y: 0, width: width, height: bounds.height)
            leadingInset = pinyinLabel.frame.maxX
        } else {
            pinyinLabel.frame = .zero
        }

        guard !buttons.isEmpty else { return }
        let availableWidth = max(0, bounds.width - leadingInset)
        let width = availableWidth / CGFloat(buttons.count)
        for (index, button) in buttons.enumerated() {
            button.frame = CGRect(x: leadingInset + CGFloat(index) * width, y: 0, width: width, height: bounds.height)
        }
    }
}
