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
        // Standard ETDRS calculation: 5 arcminutes at 20/20 vision at designated testing distance
        // Visual angle in radians = (size in arcmin / 60) * (pi/180)
        let arcmin_per_letter = 5.0 // Standard size for 20/20 optotype is 5 arcmin
        let visual_angle = ((Double(dAcuity) / 20.0) * arcmin_per_letter / 60.0) * Double.pi / 180.0
        let scaling_correction_factor = 1.0 / 2.54  // Conversion from inches to cm
        
        // Calculate size at viewing distance (no longer using factor of 2)
        let scale_factor = Double(averageDistanceCM) * tan(visual_angle) * scaling_correction_factor
        let buttonHeight = scale_factor * Double(ppi)
        let fontSize = 0.6 * buttonHeight // Slightly reducing font size ratio 
        
        button.setTitle(letText, for: .normal)
        button.titleLabel?.font = UIFont(name: "Sloan", size: CGFloat(fontSize))
        button.frame.size = CGSize(width: buttonHeight * 5, height: buttonHeight) // Standard 5:1 width to height ratio for optotypes
    }

    @IBAction func option1(_ sender: Any) {
        selectedAcuity = 200
        print("Selected acuity set to: 200")
        proceedToTest()
    }
    @IBAction func option2(_ sender: Any) {
        selectedAcuity = 160
        print("Selected acuity set to: 160")
        proceedToTest()
    }
    @IBAction func option3(_ sender: Any) {
        selectedAcuity = 125
        print("Selected acuity set to: 125")
        proceedToTest()
    }

    @IBAction func option4(_ sender: Any) {
        selectedAcuity = 100
        print("Selected acuity set to: 100")
        proceedToTest()
    }
    @IBAction func option5(_ sender: Any) {
        selectedAcuity = 80
        print("Selected acuity set to: 80")
        proceedToTest()
    }
    @IBAction func option6(_ sender: Any) {
        selectedAcuity = 63
        print("Selected acuity set to: 63")
        proceedToTest()
    }

    @IBAction func option7(_ sender: Any) {
        selectedAcuity = 50
        print("Selected acuity set to: 50")
        proceedToTest()
    }

    @IBAction func option8(_ sender: Any) {
        selectedAcuity = 40
        print("Selected acuity set to: 40")
        proceedToTest()
    }
    
    @IBAction func option9(_ sender: Any) {
        selectedAcuity = 32
        print("Selected acuity set to: 32")
        proceedToTest()
    }
    
    @IBAction func option10(_ sender: Any) {
        selectedAcuity = 20
        print("Selected acuity set to: 20")
        proceedToTest()
    }
    
    private func proceedToTest() {
        // This function ensures that selectedAcuity is saved before transitioning
        // You might need to adjust this based on your segue method
        print("Proceeding to test with acuity: \(String(describing: selectedAcuity))")
        
        // If you're using a storyboard segue, you might have something like:
        // performSegue(withIdentifier: "GoToTumblingETest", sender: self)
        
        // Or if you're using programmatic navigation:
        // let tumblingEVC = TumblingEViewController()
        // navigationController?.pushViewController(tumblingEVC, animated: true)
    }
    
    // If you're using prepareForSegue, make sure selectedAcuity is passed correctly
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        print("Preparing for segue with acuity: \(String(describing: selectedAcuity))")
        // No need to set selectedAcuity on the destination since it's a global variable,
        // but you may want to set other properties
    }
}
