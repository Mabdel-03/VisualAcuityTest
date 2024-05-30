//
//  Select_Acuity.swift
//  Distance Measure Test
//
//  Created by Maggie Bao on 5/14/24.
//

import UIKit

var selectedAcuity: Int?

class Select_Acuity: UIViewController {
    
    @IBOutlet weak var B200: UIButton!
    @IBOutlet weak var B160: UIButton!
    @IBOutlet weak var B100: UIButton!
    @IBOutlet weak var B125: UIButton!
    @IBOutlet weak var B80: UIButton!
    @IBOutlet weak var B63: UIButton!
    @IBOutlet weak var B50: UIButton!
    @IBOutlet weak var B40: UIButton!
    


    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureButtons()
    }
    
    func configureButtons() {
        setButtonTextSize(button: B200, acuity: 200)
        setButtonTextSize(button: B160, acuity: 160)
        setButtonTextSize(button: B125, acuity: 125)
        setButtonTextSize(button: B100, acuity: 100)
        setButtonTextSize(button: B80, acuity: 80)
        setButtonTextSize(button: B63, acuity: 63)
        setButtonTextSize(button: B50, acuity: 50)
        setButtonTextSize(button: B40, acuity: 40)
    }
    
    func setButtonTextSize(button: UIButton, acuity: Int) {
        let randomLetter = randomLetters(size: 1)
        Button_ETDRS(button, desired_acuity: acuity, letterText: randomLetter)
    }
    
    func Button_ETDRS(_ button: UIButton, desired_acuity: Int, letterText: String?) -> String? {
        let visual_angle = tan(((Double(desired_acuity) / 20) * 5.0 / 60) * Double.pi / 180)
        let scale_factor = 2 * Double(averageDistanceCM) * visual_angle

        guard let nonNilLetterText = letterText else {
            return nil // Return nil if letterText is nil
        }
        
        button.setTitle(spaceBetweenCharacters(input: nonNilLetterText), for: .normal)
        
        // Calculate the font size based on desired_acuity and scale_factor
        let fontSize = scale_factor * 2 * Double(ppi)
        
        print("Calculated Font Size: \(fontSize)") // Debugging print statement
        
        // Set the font size of the button's titleLabel
        button.titleLabel?.font = UIFont(name: "OpticiansansRegular-0pnR.otf", size: CGFloat(fontSize))
        
        // Force layout update
        button.layoutIfNeeded()
        
        return nonNilLetterText // Return the text that was set
    }



    
    @IBAction func acuityButtonPressed(_ sender: UIButton) {
        switch sender {
        case B200:
            selectedAcuity = 1
        case B160:
            selectedAcuity = 2
        case B125:
            selectedAcuity = 3
        case B100:
            selectedAcuity = 4
        case B80:
            selectedAcuity = 5
        case B63:
            selectedAcuity = 6
        case B50:
            selectedAcuity = 7
        case B40:
            selectedAcuity = 8
        default:
            selectedAcuity = 8
        }
        if let acuity = selectedAcuity {
            print("Selected acuity: \(acuity)")
        }
    }
    
    func spaceBetweenCharacters(input: String) -> String {
        return input.map { String($0) }.joined(separator: " ")
    }
    
    func randomLetters(size: Int) -> String {
        let validLetters = ["S", "K", "H", "N", "O", "C", "D", "V", "R", "Z"]
        let shuffledLetters = validLetters.shuffled()
        let randomLettersArray = shuffledLetters.prefix(size)
        return randomLettersArray.map { String($0) }.joined()
    }


    
    
    
    
    
}
