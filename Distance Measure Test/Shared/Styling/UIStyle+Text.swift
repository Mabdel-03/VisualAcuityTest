//
//  UIStyle+Text.swift
//  Distance Measure Test
//
//  Provides shared typography helpers for headers and instruction text.
//

import UIKit
import DevicePpi

final class PaddedStatusLabel: UILabel {
    var textInsets = UIEdgeInsets(top: 7, left: 14, bottom: 7, right: 14) {
        didSet {
            invalidateIntrinsicContentSize()
        }
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + textInsets.left + textInsets.right,
            height: size.height + textInsets.top + textInsets.bottom
        )
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: textInsets))
    }
}

enum TextPalette {
    static let magenta = UIColor(red: 0.788, green: 0.169, blue: 0.369, alpha: 1.0)
    static let teal = UIColor(red: 0.224, green: 0.424, blue: 0.427, alpha: 1.0)
    static let ink = UIColor(red: 0.15, green: 0.20, blue: 0.23, alpha: 1.0)
    static let mist = UIColor(red: 0.93, green: 0.96, blue: 0.95, alpha: 1.0)
    static let blush = UIColor(red: 0.98, green: 0.93, blue: 0.95, alpha: 1.0)
}

enum VisualAcuitySession {
    static var finalAcuityResults: [Int: String] = [:]
    static var currentEyeNumber: Int = 2
    static var selectedAcuity: Int?
    static var logMARValue: Double = -1.000
    static var snellenValue: Double = -1

    static let devicePPI: Double = {
        switch Ppi.get() {
        case .success(let ppi):
            return ppi
        case .unknown(let bestGuessPpi, _):
            return bestGuessPpi
        }
    }()

    static func eyeName(for eyeNumber: Int) -> String {
        eyeNumber == 2 ? "Right" : "Left"
    }

    static func resetResults() {
        finalAcuityResults.removeAll()
        currentEyeNumber = 2
        logMARValue = -1.000
        snellenValue = -1
    }
}

private protocol TextStylable: AnyObject {
    func setStyleFont(_ font: UIFont)
    func setStyleTextColor(_ color: UIColor)
}

extension UILabel: TextStylable {
    func setStyleFont(_ font: UIFont) {
        self.font = font
    }
    
    func setStyleTextColor(_ color: UIColor) {
        textColor = color
    }
}

extension UITextField: TextStylable {
    func setStyleFont(_ font: UIFont) {
        self.font = font
    }
    
    func setStyleTextColor(_ color: UIColor) {
        textColor = color
    }
}

public extension UILabel {
    func drawHeader() {
        font = UIFont.systemFont(ofSize: 40, weight: .bold)
        textColor = TextPalette.magenta
    }
    
    func drawHeader2() {
        font = UIFont.systemFont(ofSize: 35, weight: .semibold)
        textColor = TextPalette.teal
    }
    
    func drawInstruction() {
        font = UIFont.systemFont(ofSize: 30, weight: .regular)
        textColor = .black
    }
    
    func drawSmallText() {
        font = UIFont.systemFont(ofSize: 18, weight: .regular)
        textColor = .darkGray
    }

    func applyEyeTestTitle(eyeName: String, testName: String) {
        let title = NSMutableAttributedString()
        let lineBreak = NSAttributedString(string: "\n")

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineSpacing = 2

        title.append(
            NSAttributedString(
                string: "\(eyeName) Eye Test",
                attributes: [
                    .font: UIFont.systemFont(ofSize: 33, weight: .bold),
                    .foregroundColor: TextPalette.ink,
                    .paragraphStyle: paragraph
                ]
            )
        )
        title.append(lineBreak)
        title.append(
            NSAttributedString(
                string: testName.uppercased(),
                attributes: [
                    .font: UIFont.systemFont(ofSize: 17, weight: .black),
                    .foregroundColor: TextPalette.magenta,
                    .kern: 1.8,
                    .paragraphStyle: paragraph
                ]
            )
        )

        attributedText = title
        numberOfLines = 0
        textAlignment = .center
    }
}

public extension UITextField {
    func drawHeader() {
        font = UIFont.systemFont(ofSize: 40, weight: .bold)
        textColor = TextPalette.magenta
    }
    
    func drawHeader2() {
        font = UIFont.systemFont(ofSize: 35, weight: .semibold)
        textColor = TextPalette.teal
    }
    
    func drawInstruction() {
        font = UIFont.systemFont(ofSize: 30, weight: .regular)
        textColor = .black
    }
    
    func drawSmallText() {
        font = UIFont.systemFont(ofSize: 18, weight: .regular)
        textColor = .darkGray
    }
}

public extension UIButton {
    func drawStandardButton() {
        backgroundColor = TextPalette.teal
        setTitleColor(.white, for: .normal)
        titleLabel?.font = UIFont.systemFont(ofSize: 35, weight: .regular)
        layer.cornerRadius = 8
        layer.masksToBounds = true
    }
}

public extension UIViewController {
    func makeEndTestBarButton(action: Selector) -> UIBarButtonItem {
        let endButton = UIBarButtonItem(
            title: "End Test",
            style: .plain,
            target: self,
            action: action
        )
        endButton.tintColor = .systemRed
        return endButton
    }
}

// MARK: - Decorative Daisy Flowers

/* DaisyFlowerView creates a simple daisy flower silhouette for decorative purposes.
   The flower consists of a center circle with long, narrow petals arranged radially around it.
*/
class DaisyFlowerView: UIView {
    
    private let numberOfPetals: Int
    private let petalColor: UIColor
    private let centerColor: UIColor
    
    init(numberOfPetals: Int = 16, petalColor: UIColor, centerColor: UIColor) {
        self.numberOfPetals = numberOfPetals
        self.petalColor = petalColor
        self.centerColor = centerColor
        super.init(frame: .zero)
        self.backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        self.numberOfPetals = 16
        self.petalColor = .white
        self.centerColor = .yellow
        super.init(coder: coder)
        self.backgroundColor = .clear
    }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        let centerPoint = CGPoint(x: rect.width / 2, y: rect.height / 2)
        let centerRadius = min(rect.width, rect.height) / 8  // Smaller center
        let petalLength = min(rect.width, rect.height) / 2 - centerRadius  // Longer petals
        let petalWidth = centerRadius * 0.8  // Much narrower petals
        
        // Draw petals
        context.saveGState()
        context.translateBy(x: centerPoint.x, y: centerPoint.y)
        
        for i in 0..<numberOfPetals {
            let angle = CGFloat(i) * (2 * .pi / CGFloat(numberOfPetals))
            
            context.saveGState()
            context.rotate(by: angle)
            
            // Draw petal as a narrow ellipse
            let petalRect = CGRect(
                x: centerRadius,
                y: -petalWidth / 2,
                width: petalLength,
                height: petalWidth
            )
            
            context.setFillColor(petalColor.cgColor)
            context.fillEllipse(in: petalRect)
            
            context.restoreGState()
        }
        
        context.restoreGState()
        
        // Draw center circle
        let centerRect = CGRect(
            x: centerPoint.x - centerRadius,
            y: centerPoint.y - centerRadius,
            width: centerRadius * 2,
            height: centerRadius * 2
        )
        context.setFillColor(centerColor.cgColor)
        context.fillEllipse(in: centerRect)
    }
}

/* Extension to UIViewController for easily adding decorative daisy flowers.
*/
public extension UIViewController {
    
    /* Adds a decorative daisy flower to the view with specified parameters.
    */
    func addDecorativeDaisy(
        size: CGFloat,
        petalColor: UIColor,
        centerColor: UIColor,
        alpha: CGFloat = 1.0,
        leadingOffset: CGFloat? = nil,
        trailingOffset: CGFloat? = nil,
        topOffset: CGFloat? = nil,
        bottomOffset: CGFloat? = nil
    ) {
        let daisyView = DaisyFlowerView(
            numberOfPetals: 16,
            petalColor: petalColor.withAlphaComponent(alpha),
            centerColor: centerColor.withAlphaComponent(alpha * 0.8)
        )
        daisyView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(daisyView)
        view.sendSubviewToBack(daisyView)
        
        var constraints: [NSLayoutConstraint] = [
            daisyView.widthAnchor.constraint(equalToConstant: size),
            daisyView.heightAnchor.constraint(equalToConstant: size)
        ]
        
        // Horizontal positioning
        if let leadingOffset = leadingOffset {
            if leadingOffset < 0 {
                constraints.append(daisyView.trailingAnchor.constraint(equalTo: view.leadingAnchor, constant: -leadingOffset))
            } else {
                constraints.append(daisyView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: leadingOffset))
            }
        } else if let trailingOffset = trailingOffset {
            if trailingOffset < 0 {
                constraints.append(daisyView.leadingAnchor.constraint(equalTo: view.trailingAnchor, constant: trailingOffset))
            } else {
                constraints.append(daisyView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -trailingOffset))
            }
        }
        
        // Vertical positioning
        if let topOffset = topOffset {
            if topOffset < 0 {
                constraints.append(daisyView.bottomAnchor.constraint(equalTo: view.topAnchor, constant: -topOffset))
            } else {
                constraints.append(daisyView.topAnchor.constraint(equalTo: view.topAnchor, constant: topOffset))
            }
        } else if let bottomOffset = bottomOffset {
            if bottomOffset < 0 {
                constraints.append(daisyView.topAnchor.constraint(equalTo: view.bottomAnchor, constant: bottomOffset))
            } else {
                constraints.append(daisyView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -bottomOffset))
            }
        }
        
        NSLayoutConstraint.activate(constraints)
    }
}
