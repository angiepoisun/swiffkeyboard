import UIKit

/// The horizontal strip of accented/alternate characters shown above a key
/// on long-press, matching the standard iOS keyboard convention. The base
/// character (what a plain tap would have inserted) is always the first
/// option, so releasing without dragging is equivalent to a normal tap.
final class KeyVariantPopupView: UIView {
    let options: [String]
    private var labels: [UILabel] = []
    private(set) var selectedIndex = 0

    init(options: [String]) {
        self.options = options
        super.init(frame: .zero)
        backgroundColor = KeyboardTheme.controlKey
        layer.cornerRadius = 8
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowRadius = 4
        layer.shadowOffset = CGSize(width: 0, height: 2)

        labels = options.map { option in
            let label = UILabel()
            label.text = option
            label.textAlignment = .center
            label.font = .systemFont(ofSize: 22, weight: .regular)
            label.textColor = .label
            label.clipsToBounds = true
            addSubview(label)
            return label
        }
        updateSelection(index: 0)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func updateSelection(index: Int) {
        guard options.indices.contains(index) else { return }
        selectedIndex = index
        for (i, label) in labels.enumerated() {
            label.backgroundColor = i == index ? KeyboardTheme.accent.withAlphaComponent(0.3) : .clear
            label.layer.cornerRadius = 6
        }
    }

    /// Which option index a given x position (in this view's own
    /// coordinate space) corresponds to, clamped to the valid range so
    /// dragging past either edge just holds the nearest option.
    func index(forX x: CGFloat) -> Int {
        guard !options.isEmpty, bounds.width > 0 else { return 0 }
        let step = bounds.width / CGFloat(options.count)
        return max(0, min(options.count - 1, Int(x / step)))
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !labels.isEmpty else { return }
        let width = bounds.width / CGFloat(labels.count)
        for (index, label) in labels.enumerated() {
            label.frame = CGRect(x: CGFloat(index) * width, y: 0, width: width, height: bounds.height)
        }
    }
}
