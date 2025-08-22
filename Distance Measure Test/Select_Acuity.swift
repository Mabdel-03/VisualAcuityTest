//
//  Select_Acuity.swift
//  Distance Measure Test
//
//  Created by Maggie Bao on 5/14/24.
//

import UIKit
import AVFoundation

let LETTER = "C" // Landold C-- the letter that is displayed on the acuity selection scene.
var selectedAcuity: Int?

/* Select_Acuity class is designed to display the acuity selection scene.
    On this page, the user is given a list of acuity levels to start the test at.
*/
class Select_Acuity: UIViewController {
    
    @IBOutlet weak var B200: UIButton!
    @IBOutlet weak var B160: UIButton!
    @IBOutlet weak var B100: UIButton!
    @IBOutlet weak var B125: UIButton!
    @IBOutlet weak var B80: UIButton!
    @IBOutlet weak var B63: UIButton!
    @IBOutlet weak var B50: UIButton!
    @IBOutlet weak var B40: UIButton!
    @IBOutlet weak var B20: UIButton!
    @IBOutlet weak var B10: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print(averageDistanceCM)
        
        // Set up all buttons with their appropriate letter sizes
        Button_ETDRS(B200, dAcuity: 200, letText: LETTER)
        Button_ETDRS(B160, dAcuity: 160, letText: LETTER)
        Button_ETDRS(B125, dAcuity: 125, letText: LETTER)
        Button_ETDRS(B100, dAcuity: 100, letText: LETTER)
        Button_ETDRS(B80, dAcuity: 80, letText: LETTER)
        Button_ETDRS(B63, dAcuity: 63, letText: LETTER)
        Button_ETDRS(B50, dAcuity: 50, letText: LETTER)
        Button_ETDRS(B40, dAcuity: 40, letText: LETTER)
        Button_ETDRS(B20, dAcuity: 32, letText: LETTER)
        Button_ETDRS(B10, dAcuity: 20, letText: LETTER)
        
        // Configure the stack view and buttons for dynamic sizing
        configureButtonConstraints()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        playAudioInstructions()
    }
    
    /* Plays audio instructions to the user.
    */
    private func playAudioInstructions() {
        let instructionText = "Choose your starting acuity level by tapping one of the letter options. The letters are sized according to different vision levels. Select the largest letter you can clearly see to begin your test."
        SharedAudioManager.shared.playText(instructionText, source: "Acuity Selection")
    }
    
    /* Sets up the button text size and display for the acuity selection scene.
    */
    func Button_ETDRS(_ button: UIButton, dAcuity: Int, letText: String) {
        // Standard ETDRS calculation: 5 arcminutes at 20/20 vision at designated testing distance
        // Visual angle in radians = (size in arcmin / 60) * (pi/180)
        let arcmin_per_letter = 5.0 // Standard size for 20/20 optotype is 5 arcmin
        let visual_angle = ((Double(dAcuity) / 20.0) * arcmin_per_letter / 60.0) * Double.pi / 180.0
        let scaling_correction_factor = 1.0 / 2.54  // Conversion from inches to cm
        
        // Calculate size at viewing distance
        let scale_factor = Double(averageDistanceCM) * tan(visual_angle) * scaling_correction_factor
        let letterHeight = scale_factor * Double(ppi)
        
        // Adjusted font size - reducing by factor of 2 to match physical acuity cards
        // The 0.3 factor (instead of 0.6) accounts for font rendering differences
        let fontSize = 0.3 * letterHeight 
        
        button.setTitle(letText, for: .normal)
        button.titleLabel?.font = UIFont(name: "Sloan", size: CGFloat(fontSize))
        
        // Calculate appropriate padding based on letter size for full-width buttons
        let verticalPadding: CGFloat = 20 + (CGFloat(fontSize) * 0.15) // Scale vertical padding with font size
        let horizontalPadding: CGFloat = 16 // Minimal horizontal padding since button spans full width
        
        // Set content edge insets optimized for full-width layout
        button.contentEdgeInsets = UIEdgeInsets(
            top: verticalPadding,      // Adequate vertical padding
            left: horizontalPadding,   // Minimal horizontal padding
            bottom: verticalPadding,   // Adequate vertical padding
            right: horizontalPadding   // Minimal horizontal padding
        )
        
        // Configure button appearance for better visual feedback
        button.layer.cornerRadius = 12 // Slightly larger radius for full-width buttons
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.lightGray.cgColor
        button.backgroundColor = UIColor.systemBackground
        
        // Ensure text is centered in the full-width button
        button.titleLabel?.textAlignment = .center
        button.contentHorizontalAlignment = .center
        button.contentVerticalAlignment = .center
        
        // Set content hugging and compression priorities for full-width layout
        button.setContentHuggingPriority(.defaultLow, for: .horizontal)  // Allow horizontal expansion
        button.setContentHuggingPriority(.required, for: .vertical)      // Keep tight vertical sizing
        button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal) // Allow compression if needed
        button.setContentCompressionResistancePriority(.required, for: .vertical)     // Resist vertical compression
        
        // Debug output to verify scaling
        let intrinsicSize = button.intrinsicContentSize
        print("Acuity: \(dAcuity), Letter height: \(letterHeight)px, Font size: \(fontSize)pt, Button intrinsic size: \(intrinsicSize.width)x\(intrinsicSize.height)px, V-Padding: \(verticalPadding)px")
    }

    //DIFFERENT ACUITY LEVELS

    @IBAction func option1(_ sender: Any) {
        selectedAcuity = 200
        proceedToTest()
    }
    @IBAction func option2(_ sender: Any) {
        selectedAcuity = 160
        proceedToTest()
    }
    @IBAction func option3(_ sender: Any) {
        selectedAcuity = 125
        proceedToTest()
    }

    @IBAction func option4(_ sender: Any) {
        selectedAcuity = 100
        proceedToTest()
    }
    @IBAction func option5(_ sender: Any) {
        selectedAcuity = 80
        proceedToTest()
    }
    @IBAction func option6(_ sender: Any) {
        selectedAcuity = 63
        proceedToTest()
    }

    @IBAction func option7(_ sender: Any) {
        selectedAcuity = 50
        proceedToTest()
    }

    @IBAction func option8(_ sender: Any) {
        selectedAcuity = 40
        proceedToTest()
    }
    
    @IBAction func option9(_ sender: Any) {
        selectedAcuity = 32
        proceedToTest()
    }
    
    @IBAction func option10(_ sender: Any) {
        selectedAcuity = 20
        proceedToTest()
    }
    
    /* This function ensures that selectedAcuity is saved before transitioning
        to the test scene.
    */
    private func proceedToTest() {
        print("Proceeding to test with acuity: \(String(describing: selectedAcuity))")
    }
    
    /* Configures the button constraints for the acuity selection scene.
    */
    private func configureButtonConstraints() {
        // Get all the buttons
        let buttons = [B200, B160, B125, B100, B80, B63, B50, B40, B20, B10]
        
        // Configure the stack view for full-width buttons
        if let firstButton = buttons.compactMap({ $0 }).first,
           let stackView = firstButton.superview as? UIStackView {
            stackView.distribution = .fillEqually
            stackView.alignment = .fill
            stackView.spacing = 8 // Add some spacing between buttons
            print("✅ Stack view configured: distribution=fillEqually, alignment=fill, spacing=8")
        } else {
            print("⚠️ Could not find stack view - buttons may not be in a UIStackView")
        }
        
        for button in buttons {
            guard let button = button else { continue }
            
            // Remove any existing height constraints that were set to 200 in the storyboard
            button.constraints.forEach { constraint in
                if constraint.firstAttribute == .height && constraint.constant == 200 {
                    constraint.isActive = false
                    print("🔧 Removed 200px height constraint from button")
                }
            }
            
            // Also check constraints from the superview (stack view)
            if let stackView = button.superview {
                stackView.constraints.forEach { constraint in
                    if (constraint.firstItem as? UIButton) == button && 
                       constraint.firstAttribute == .height && 
                       constraint.constant == 200 {
                        constraint.isActive = false
                        print("🔧 Removed 200px height constraint from stack view")
                    }
                }
            }
            
            // Configure button to expand horizontally while maintaining dynamic height
            button.setContentHuggingPriority(.defaultLow, for: .horizontal) // Allow horizontal expansion
            button.setContentHuggingPriority(.required, for: .vertical)     // Keep tight vertical sizing
            button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal) // Allow compression if needed
            button.setContentCompressionResistancePriority(.required, for: .vertical)     // Resist vertical compression
        }
        
        // Force layout update to apply the new sizing
        view.setNeedsLayout()
        view.layoutIfNeeded()
        
        print("✅ Button constraints configured for full-width dynamic sizing")
    }
}
