import UIKit

protocol EmojiPadDelegate: AnyObject {
    func emojiPad(_ pad: EmojiPadView, didSelect emoji: String)
    func emojiPadDidTapBackspace(_ pad: EmojiPadView)
    func emojiPadDidTapABC(_ pad: EmojiPadView)
}

final class EmojiPadView: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    weak var delegate: EmojiPadDelegate?

    private let categoryBar = UIScrollView()
    private var categoryButtons: [UIButton] = []
    private let collectionView: UICollectionView
    private let abcButton = KeyButton(definition: .toLetters)
    private let backspaceButton = KeyButton(definition: .backspace)

    private var selectedCategoryIndex = 1
    private var currentEmoji: [String] = []
    private var recentEmoji: [String] {
        get { AppGroup.defaults.stringArray(forKey: AppGroup.Key.recentEmoji) ?? [] }
        set { AppGroup.defaults.set(Array(newValue.prefix(30)), forKey: AppGroup.Key.recentEmoji) }
    }

    override init(frame: CGRect) {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 2
        layout.minimumLineSpacing = 2
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: frame)

        backgroundColor = .clear
        collectionView.backgroundColor = .clear
        collectionView.register(EmojiCell.self, forCellWithReuseIdentifier: EmojiCell.reuseID)
        collectionView.dataSource = self
        collectionView.delegate = self
        addSubview(collectionView)

        categoryBar.showsHorizontalScrollIndicator = false
        addSubview(categoryBar)
        for (index, category) in EmojiLayout.categories.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(category.symbol, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 18)
            button.tag = index
            button.addTarget(self, action: #selector(categoryTapped(_:)), for: .touchUpInside)
            categoryBar.addSubview(button)
            categoryButtons.append(button)
        }

        abcButton.configure()
        backspaceButton.configure()
        addSubview(abcButton)
        addSubview(backspaceButton)
        let abcTap = UITapGestureRecognizer(target: self, action: #selector(abcTapped))
        abcButton.isUserInteractionEnabled = true
        abcButton.addGestureRecognizer(abcTap)
        let backspaceTap = UITapGestureRecognizer(target: self, action: #selector(backspaceTapped))
        backspaceButton.isUserInteractionEnabled = true
        backspaceButton.addGestureRecognizer(backspaceTap)

        selectCategory(recentEmoji.isEmpty ? 1 : 0)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let categoryBarHeight: CGFloat = 36
        let controlBarHeight: CGFloat = 44
        categoryBar.frame = CGRect(x: 0, y: 0, width: bounds.width, height: categoryBarHeight)
        var x: CGFloat = 4
        for button in categoryButtons {
            button.frame = CGRect(x: x, y: 0, width: 36, height: categoryBarHeight)
            x += 40
        }
        categoryBar.contentSize = CGSize(width: x, height: categoryBarHeight)

        collectionView.frame = CGRect(
            x: 0, y: categoryBarHeight,
            width: bounds.width,
            height: bounds.height - categoryBarHeight - controlBarHeight
        )

        let barY = bounds.height - controlBarHeight
        abcButton.frame = CGRect(x: 4, y: barY + 3, width: bounds.width * 0.2, height: controlBarHeight - 6)
        backspaceButton.frame = CGRect(x: bounds.width - bounds.width * 0.2 - 4, y: barY + 3, width: bounds.width * 0.2, height: controlBarHeight - 6)
    }

    @objc private func categoryTapped(_ sender: UIButton) {
        selectCategory(sender.tag)
    }

    @objc private func abcTapped() {
        delegate?.emojiPadDidTapABC(self)
    }

    @objc private func backspaceTapped() {
        delegate?.emojiPadDidTapBackspace(self)
    }

    private func selectCategory(_ index: Int) {
        selectedCategoryIndex = index
        currentEmoji = index == 0 ? recentEmoji : EmojiLayout.categories[index].emoji
        for (i, button) in categoryButtons.enumerated() {
            button.alpha = i == index ? 1.0 : 0.4
        }
        collectionView.reloadData()
        collectionView.setContentOffset(.zero, animated: false)
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        currentEmoji.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: EmojiCell.reuseID, for: indexPath) as! EmojiCell
        cell.label.text = currentEmoji[indexPath.item]
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let emoji = currentEmoji[indexPath.item]
        var recents = recentEmoji
        recents.removeAll { $0 == emoji }
        recents.insert(emoji, at: 0)
        recentEmoji = recents
        delegate?.emojiPad(self, didSelect: emoji)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let columns: CGFloat = 7
        let side = (bounds.width - (columns + 1) * 2) / columns
        return CGSize(width: side, height: side)
    }
}

private final class EmojiCell: UICollectionViewCell {
    static let reuseID = "EmojiCell"
    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = .systemFont(ofSize: 28)
        label.textAlignment = .center
        contentView.addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = bounds
    }
}
