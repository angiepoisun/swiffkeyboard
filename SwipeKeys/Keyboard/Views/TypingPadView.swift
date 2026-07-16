import UIKit

protocol TypingPadDelegate: AnyObject {
    func typingPad(_ pad: TypingPadView, didTapKey key: KeyDefinition)
    func typingPad(_ pad: TypingPadView, didFinishGlide word: String, alternates: [String])
    func typingPadDidDoubleTapShift(_ pad: TypingPadView)
}

/// Renders one keyboard page (number row + letters, or a symbols page) and
/// owns all touch handling for it: a quick tap types a letter, a drag across
/// several keys without lifting is captured as a glide-typing path and
/// handed to `GlideTypingEngine`. On non-glideable pages (symbols) a drag
/// still lets you "slide to select" the key you release on, matching
/// standard iOS keyboard behavior.
final class TypingPadView: UIView {
    weak var delegate: TypingPadDelegate?
    var dictionary: WordFrequencyDictionary?

    private(set) var page = KeyboardPage(rows: [])
    private var isShifted = false
    private var isCapsLocked = false
    private var glideEnabled = true

    private var rows: [[KeyButton]] = []
    private var allButtons: [KeyButton] = []

    private let trailLayer = CAShapeLayer()
    private var currentPath: [CGPoint] = []
    private var isGliding = false
    private var touchStartButton: KeyButton?
    private var hoveredButton: KeyButton?
    private var backspaceRepeatTimer: Timer?
    private var lastShiftTapTime: TimeInterval = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        trailLayer.strokeColor = KeyboardTheme.accent.withAlphaComponent(0.55).cgColor
        trailLayer.fillColor = UIColor.clear.cgColor
        trailLayer.lineWidth = 4
        trailLayer.lineCap = .round
        trailLayer.lineJoin = .round
        layer.addSublayer(trailLayer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setPage(_ page: KeyboardPage, shifted: Bool, capsLocked: Bool, glideEnabled: Bool) {
        self.page = page
        self.isShifted = shifted
        self.isCapsLocked = capsLocked
        self.glideEnabled = glideEnabled
        rebuild()
    }

    func updateShiftAppearance(shifted: Bool, capsLocked: Bool) {
        isShifted = shifted
        isCapsLocked = capsLocked
        for button in allButtons {
            applyState(to: button)
        }
    }

    private func rebuild() {
        allButtons.forEach { $0.removeFromSuperview() }
        rows = page.rows.map { row in
            row.map { definition -> KeyButton in
                let button = KeyButton(definition: definition)
                addSubview(button)
                return button
            }
        }
        allButtons = rows.flatMap { $0 }
        allButtons.forEach { applyState(to: $0) }
        setNeedsLayout()
    }

    private func applyState(to button: KeyButton) {
        switch button.definition {
        case .char(let base):
            button.configure(displayText: (isShifted || isCapsLocked) ? base.uppercased() : base)
        case .shift:
            button.configure(isShiftActive: isShifted, isCapsLocked: isCapsLocked)
        default:
            button.configure()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !rows.isEmpty else { return }
        let rowHeight = bounds.height / CGFloat(rows.count)
        for (rowIndex, row) in rows.enumerated() {
            layout(row: row, y: CGFloat(rowIndex) * rowHeight, height: rowHeight)
        }
    }

    private func layout(row: [KeyButton], y: CGFloat, height: CGFloat) {
        let weights = row.map(weight(for:))
        let totalWeight = weights.reduce(0, +)
        guard totalWeight > 0 else { return }
        let unit = bounds.width / totalWeight
        var x: CGFloat = 0
        let inset: CGFloat = 3
        for (button, w) in zip(row, weights) {
            let width = unit * w
            button.frame = CGRect(x: x + inset, y: y + inset, width: width - inset * 2, height: height - inset * 2)
            x += width
        }
    }

    private func weight(for definition: KeyDefinition) -> CGFloat {
        switch definition {
        case .shift, .backspace: return 1.5
        case .toSymbols1, .toSymbols2, .toLetters: return 1.3
        default: return 1.0
        }
    }

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)
        currentPath = [point]
        isGliding = false
        let button = self.button(at: point)
        touchStartButton = button
        hoveredButton = button
        button?.isKeyHighlighted = true

        if case .backspace = button?.definition {
            startBackspaceRepeat()
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)
        currentPath.append(point)

        if glideEnabled, !isGliding, let start = currentPath.first, point.distance(to: start) > 16 {
            isGliding = true
            cancelBackspaceRepeat()
        }
        if isGliding {
            updateTrail()
            return
        }

        let newHover = button(at: point)
        if newHover !== hoveredButton {
            hoveredButton?.isKeyHighlighted = false
            newHover?.isKeyHighlighted = true
            hoveredButton = newHover
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        defer {
            allButtons.forEach { $0.isKeyHighlighted = false }
            cancelBackspaceRepeat()
            clearTrail()
            isGliding = false
        }

        if isGliding {
            finishGlide()
            return
        }

        if let button = hoveredButton {
            handleTap(on: button)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        allButtons.forEach { $0.isKeyHighlighted = false }
        clearTrail()
        isGliding = false
        cancelBackspaceRepeat()
    }

    private func handleTap(on button: KeyButton) {
        if case .shift = button.definition {
            let now = CACurrentMediaTime()
            if now - lastShiftTapTime < 0.35 {
                lastShiftTapTime = 0
                delegate?.typingPadDidDoubleTapShift(self)
                return
            }
            lastShiftTapTime = now
        }
        delegate?.typingPad(self, didTapKey: button.definition)
    }

    private func finishGlide() {
        guard let dictionary else { return }
        let keyCenters = glideKeyCenters()
        let results = GlideTypingEngine.candidates(forPath: currentPath, keyCenters: keyCenters, dictionary: dictionary)
        guard !results.isEmpty else { return }
        delegate?.typingPad(self, didFinishGlide: results[0], alternates: Array(results.dropFirst()))
    }

    private func glideKeyCenters() -> [Character: CGPoint] {
        var centers: [Character: CGPoint] = [:]
        for button in allButtons {
            guard case .char(let base) = button.definition,
                  let first = base.lowercased().first,
                  first.isLetter else { continue }
            centers[first] = CGPoint(x: button.frame.midX, y: button.frame.midY)
        }
        return centers
    }

    private func button(at point: CGPoint) -> KeyButton? {
        allButtons.first { $0.frame.contains(point) }
    }

    private func updateTrail() {
        guard let first = currentPath.first else { return }
        let path = UIBezierPath()
        path.move(to: first)
        for point in currentPath.dropFirst() { path.addLine(to: point) }
        trailLayer.path = path.cgPath
    }

    private func clearTrail() {
        trailLayer.path = nil
    }

    private func startBackspaceRepeat() {
        cancelBackspaceRepeat()
        backspaceRepeatTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
            self?.beginFastBackspace()
        }
    }

    private func beginFastBackspace() {
        backspaceRepeatTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.delegate?.typingPad(self, didTapKey: .backspace)
        }
    }

    private func cancelBackspaceRepeat() {
        backspaceRepeatTimer?.invalidate()
        backspaceRepeatTimer = nil
    }
}
