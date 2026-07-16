import UIKit

/// Brief centered pill ("🇪🇸 Español") shown when the spacebar-swipe
/// language switch commits, on top of the persistent flag already shown on
/// the spacebar itself.
final class LanguageToastView: UIView {
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.black.withAlphaComponent(0.75)
        layer.cornerRadius = 14
        isUserInteractionEnabled = false
        alpha = 0

        label.textColor = .white
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textAlignment = .center
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(language: SupportedLanguage, in container: UIView) {
        label.text = "\(language.flag) \(language.displayName)"
        if superview !== container {
            removeFromSuperview()
            container.addSubview(self)
        }
        sizeToFit()
        frame.size.height = 36
        center = CGPoint(x: container.bounds.midX, y: container.bounds.midY)

        layer.removeAllAnimations()
        alpha = 0
        transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        UIView.animate(withDuration: 0.15, animations: {
            self.alpha = 1
            self.transform = .identity
        }, completion: { _ in
            UIView.animate(withDuration: 0.25, delay: 0.5, options: [], animations: {
                self.alpha = 0
            })
        })
    }
}
