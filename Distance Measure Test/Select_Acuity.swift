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
        print(averageDistanceCM)
        Button_ETDRS(B200, dAcuity: 200, letText: "E")
        Button_ETDRS(B160, dAcuity: 160, letText: "E")
        Button_ETDRS(B125, dAcuity: 125, letText: "E")
        Button_ETDRS(B100, dAcuity: 100, letText: "E")
        Button_ETDRS(B80, dAcuity: 80, letText: "E")
        Button_ETDRS(B63, dAcuity: 63, letText: "E")
        Button_ETDRS(B50, dAcuity: 50, letText: "E")
        Button_ETDRS(B40, dAcuity: 40, letText: "E")
    }
    
    func Button_ETDRS(_ button: UIButton, dAcuity: Int, letText: String) {
        let visual_angle = tan(((Double(dAcuity) / 20) * 5.0 / 60) * Double.pi / 180)
        let scale_factor = 2 * Double(averageDistanceCM) * visual_angle
        let fontSize = scale_factor * 2 * Double(ppi)
        print(fontSize)
        button.titleLabel!.font = UIFont(name: "OpticianSans-Regular", size: CGFloat(fontSize))
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
}
