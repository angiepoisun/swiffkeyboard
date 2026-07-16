import UIKit

protocol SuggestionBarDelegate: AnyObject {
    func suggestionBar(_ bar: SuggestionBarView, didSelect word: String)
}

/// Strip above the keys showing the top glide/tap candidate plus
/// alternates. Tapping one replaces whatever was just inserted.
final class SuggestionBarView: UIView {
    weak var delegate: SuggestionBarDelegate?

    private var buttons: [UIButton] = []
    private var words: [String] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = KeyboardTheme.background
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

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
        guard !buttons.isEmpty else { return }
        let width = bounds.width / CGFloat(buttons.count)
        for (index, button) in buttons.enumerated() {
            button.frame = CGRect(x: CGFloat(index) * width, y: 0, width: width, height: bounds.height)
        }
    }
}
