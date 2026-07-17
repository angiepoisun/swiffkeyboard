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
    private let scrollView = UIScrollView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = KeyboardTheme.background

        pinyinLabel.font = .systemFont(ofSize: 17, weight: .regular)
        pinyinLabel.textColor = .label
        pinyinLabel.textAlignment = .left
        pinyinLabel.isUserInteractionEnabled = false
        addSubview(pinyinLabel)

        scrollView.showsHorizontalScrollIndicator = false
        addSubview(scrollView)
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
            config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12)
            config.baseForegroundColor = index == 0 ? .label : .secondaryLabel
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = .systemFont(ofSize: 16, weight: index == 0 ? .semibold : .regular)
                return outgoing
            }
            button.configuration = config
            button.tag = index
            button.addTarget(self, action: #selector(tapped(_:)), for: .touchUpInside)
            scrollView.addSubview(button)
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

        let scrollFrame = CGRect(x: leadingInset, y: 0, width: max(0, bounds.width - leadingInset), height: bounds.height)
        scrollView.frame = scrollFrame

        guard !buttons.isEmpty else {
            scrollView.contentSize = .zero
            return
        }

        // Up to ~4 candidates fill the available width evenly, same as
        // before. Past that, buttons take their natural (readable) width
        // instead of being squeezed thinner and thinner, and the bar
        // scrolls horizontally to reach the rest.
        let evenWidth = scrollFrame.width / CGFloat(min(buttons.count, 4))
        var x: CGFloat = 0
        for button in buttons {
            let natural = button.sizeThatFits(CGSize(width: .greatestFiniteMagnitude, height: scrollFrame.height)).width
            let width = max(evenWidth, natural)
            button.frame = CGRect(x: x, y: 0, width: width, height: scrollFrame.height)
            x += width
        }
        scrollView.contentSize = CGSize(width: max(x, scrollFrame.width), height: scrollFrame.height)
    }
}
