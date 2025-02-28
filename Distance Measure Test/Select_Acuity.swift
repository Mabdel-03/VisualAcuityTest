//
//  Select_Acuity.swift
//  Distance Measure Test
//
//  Created by Maggie Bao on 5/14/24.
//

import UIKit

let LETTER = "C"
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
    @IBOutlet weak var B20: UIButton!
    @IBOutlet weak var B10: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print(averageDistanceCM)
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
    }
    
    func Button_ETDRS(_ button: UIButton, dAcuity: Int, letText: String) {
        let visual_angle = ((Double(dAcuity) / 20) * 5.0 / 60) * Double.pi / 180
        let scaling_correction_factor = 1 / 2.54  //Conversion to cm
        let scale_factor = Double(averageDistanceCM) * visual_angle * scaling_correction_factor
        let buttonHeight = scale_factor * Double(ppi)
        let fontSize = 2 / 3 * buttonHeight // Using the same ratio as set_ETDRS
        button.setTitle(letText, for: .normal)
        button.titleLabel?.font = UIFont(name: "Sloan", size: CGFloat(fontSize))
        button.frame.size = CGSize(width: buttonHeight * 6, height: buttonHeight) // Assuming button width should be 6 times the height
    }

    @IBAction func option1(_ sender: Any) {
        selectedAcuity = 200
    }
    @IBAction func option2(_ sender: Any) {
        selectedAcuity = 160
    }
    @IBAction func option3(_ sender: Any) {
        selectedAcuity = 125
    }

    @IBAction func option4(_ sender: Any) {
        selectedAcuity = 100
    }
    @IBAction func option5(_ sender: Any) {
        selectedAcuity = 80
    }
    @IBAction func option6(_ sender: Any) {
        selectedAcuity = 63
    }

    @IBAction func option7(_ sender: Any) {
        selectedAcuity = 50
    }

    @IBAction func option8(_ sender: Any) {
        selectedAcuity = 40
    }
    
    @IBAction func option9(_ sender: Any) {
        selectedAcuity = 32
    }
    
    @IBAction func option10(_ sender: Any) {
        selectedAcuity = 20
    }
}
