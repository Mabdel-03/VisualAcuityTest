import UIKit

final class DistanceGuidanceView: UIView {
    private let contentStack = UIStackView()
    private enum VisibleState: Equatable {
        case hidden
        case warning
        case ok
        case moveCloser
        case moveFarther
        case customGuidance(String)
    }
    private var visibleState: VisibleState = .hidden
    private var okDismissWorkItem: DispatchWorkItem?
    
    // MARK: - Internal Labels
    
    let warningLabel = PaddedStatusLabel()
    let okLabel = PaddedStatusLabel()
    let moveCloserLabel = PaddedStatusLabel()
    let moveFartherLabel = PaddedStatusLabel()
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setIcon(_ systemName: String, tint: UIColor, text: String, for label: UILabel) {
        let attachment = NSTextAttachment()
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        if let image = UIImage(systemName: systemName, withConfiguration: config)?.withTintColor(tint, renderingMode: .alwaysOriginal) {
            attachment.image = image
        }
        let attachmentString = NSAttributedString(attachment: attachment)
        
        let attributed = NSMutableAttributedString()
        attributed.append(attachmentString)
        attributed.append(NSAttributedString(string: "  " + text))
        
        label.attributedText = attributed
    }

    private func setTwoLineMessage(
        badge: String,
        message: String,
        badgeColor: UIColor,
        messageColor: UIColor,
        for label: UILabel
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineSpacing = 2

        let text = NSMutableAttributedString(
            string: badge.uppercased(),
            attributes: [
                .font: UIFont.systemFont(ofSize: 13, weight: .black),
                .foregroundColor: badgeColor,
                .kern: 1.4,
                .paragraphStyle: paragraph
            ]
        )
        text.append(
            NSAttributedString(
                string: "\n\(message)",
                attributes: [
                    .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
                    .foregroundColor: messageColor,
                    .paragraphStyle: paragraph
                ]
            )
        )
        label.attributedText = text
    }

    private func configureLabel(_ label: PaddedStatusLabel, backgroundColor: UIColor, borderColor: UIColor) {
        label.applyStatusPillStyle(
            backgroundColor: backgroundColor,
            borderColor: borderColor,
            textInsets: UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16),
            cornerRadius: 18,
            shadowColor: AppThemeColors.black.withAlphaComponent(0.08),
            shadowOpacity: 1,
            shadowRadius: 18,
            shadowOffset: CGSize(width: 0, height: 8)
        )
    }
    
    private func setup() {
        contentStack.axis = .vertical
        contentStack.alignment = .center
        contentStack.spacing = 10
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentStack)

        configureLabel(
            warningLabel,
            backgroundColor: UIColor(red: 1.0, green: 0.95, blue: 0.93, alpha: 0.98),
            borderColor: UIColor(red: 0.93, green: 0.42, blue: 0.32, alpha: 0.35)
        )
        configureLabel(
            okLabel,
            backgroundColor: UIColor(red: 0.93, green: 0.97, blue: 0.94, alpha: 0.98),
            borderColor: UIColor(red: 0.20, green: 0.58, blue: 0.38, alpha: 0.30)
        )
        configureLabel(
            moveCloserLabel,
            backgroundColor: TextPalette.mist,
            borderColor: TextPalette.teal.withAlphaComponent(0.22)
        )
        configureLabel(
            moveFartherLabel,
            backgroundColor: TextPalette.blush,
            borderColor: TextPalette.magenta.withAlphaComponent(0.22)
        )

        contentStack.addArrangedSubview(warningLabel)
        contentStack.addArrangedSubview(okLabel)
        contentStack.addArrangedSubview(moveCloserLabel)
        contentStack.addArrangedSubview(moveFartherLabel)
        
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor),

            warningLabel.leadingAnchor.constraint(greaterThanOrEqualTo: contentStack.leadingAnchor, constant: 16),
            warningLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentStack.trailingAnchor, constant: -16),
            okLabel.leadingAnchor.constraint(greaterThanOrEqualTo: contentStack.leadingAnchor, constant: 16),
            okLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentStack.trailingAnchor, constant: -16),
            moveCloserLabel.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor, constant: 8),
            moveCloserLabel.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor, constant: -8),
            moveFartherLabel.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor, constant: 8),
            moveFartherLabel.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor, constant: -8)
        ])
        
        setIcon("exclamationmark.triangle.fill", tint: .systemRed, text: "Reposition to stay in range", for: warningLabel)
        setIcon("checkmark.circle.fill", tint: .systemGreen, text: "Distance locked in", for: okLabel)
        setTwoLineMessage(
            badge: "Too Far",
            message: "Move closer to continue",
            badgeColor: TextPalette.teal,
            messageColor: TextPalette.ink,
            for: moveCloserLabel
        )
        setTwoLineMessage(
            badge: "Too Close",
            message: "Move farther to continue",
            badgeColor: TextPalette.magenta,
            messageColor: TextPalette.ink,
            for: moveFartherLabel
        )
    }
    
    // MARK: - Fade In Helper
    
    private func fadeIn(_ label: UILabel, duration: TimeInterval = 0.2) {
        label.alpha = 0
        label.isHidden = false
        UIView.animate(withDuration: duration) {
            label.alpha = 1
        }
    }

    private func cancelPendingOKDismissal() {
        okDismissWorkItem?.cancel()
        okDismissWorkItem = nil
    }

    private func display(_ label: UILabel, for state: VisibleState, animated: Bool = true) {
        guard visibleState != state else { return }

        cancelPendingOKDismissal()
        warningLabel.isHidden = label !== warningLabel
        okLabel.isHidden = label !== okLabel
        moveCloserLabel.isHidden = label !== moveCloserLabel
        moveFartherLabel.isHidden = label !== moveFartherLabel

        warningLabel.alpha = 1
        okLabel.alpha = 1
        moveCloserLabel.alpha = 1
        moveFartherLabel.alpha = 1

        visibleState = state
        if animated {
            fadeIn(label)
        } else {
            label.isHidden = false
        }
    }
    
    // MARK: - Public Methods
    
    /// Hides all labels and resets alpha to 1
    func hideAll() {
        cancelPendingOKDismissal()
        warningLabel.isHidden = true
        okLabel.isHidden = true
        moveCloserLabel.isHidden = true
        moveFartherLabel.isHidden = true
        
        warningLabel.alpha = 1
        okLabel.alpha = 1
        moveCloserLabel.alpha = 1
        moveFartherLabel.alpha = 1
        visibleState = .hidden
    }
    
    /// Shows the warning label with fade-in and hides all others
    func showWarning() {
        display(warningLabel, for: .warning)
    }
    
    /// Shows the OK label with fade-in, optionally temporary (default true) with duration (default 1.0s)
    func showOK(temporarily: Bool = true, duration: TimeInterval = 1.0) {
        display(okLabel, for: .ok)
        
        if temporarily {
            let workItem = DispatchWorkItem { [weak self] in
                guard let self, self.visibleState == .ok else { return }
                UIView.animate(withDuration: 0.2, animations: {
                    self.okLabel.alpha = 0
                }) { _ in
                    self.okLabel.isHidden = true
                    self.okLabel.alpha = 1
                    self.visibleState = .hidden
                }
            }
            okDismissWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
        }
    }
    
    /// Shows the move closer label with fade-in and hides all others
    func showMoveCloser() {
        display(moveCloserLabel, for: .moveCloser)
    }
    
    /// Shows the move farther label with fade-in and hides all others
    func showMoveFarther() {
        display(moveFartherLabel, for: .moveFarther)
    }
    
    /// Displays a custom guidance message using the moveCloserLabel style and appearance with fade-in
    func showGuidanceMessage(_ message: String) {
        setTwoLineMessage(
            badge: "Distance Guidance",
            message: message,
            badgeColor: TextPalette.teal,
            messageColor: TextPalette.ink,
            for: moveCloserLabel
        )
        display(moveCloserLabel, for: .customGuidance(message))
    }
}
