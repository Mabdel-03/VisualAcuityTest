//
//  DaisyFlowerView.swift
//  Distance Measure Test
//
//  Created for Visual Cohesion
//

import UIKit

/* DaisyFlowerView creates a simple daisy flower silhouette for decorative purposes.
   The flower consists of a center circle with petals arranged radially around it.
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
        let petalWidth = centerRadius * 0.4  // Much narrower petals
        
        // Draw petals
        context.saveGState()
        context.translateBy(x: centerPoint.x, y: centerPoint.y)
        
        for i in 0..<numberOfPetals {
            let angle = CGFloat(i) * (2 * .pi / CGFloat(numberOfPetals))
            
            context.saveGState()
            context.rotate(by: angle)
            
            // Draw petal as an ellipse
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
extension UIViewController {
    
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
            numberOfPetals: 8,
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

