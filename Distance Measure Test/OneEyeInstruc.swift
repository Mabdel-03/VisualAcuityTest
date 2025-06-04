//
//  OneEyeInstruc.swift
//  Distance Measure Test
//
//  Created by Maggie Bao on 6/4/25.
//

import Foundation
import UIKit

class OneEyeInstruc: UIViewController {
    @IBOutlet weak var instructionText: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        instructionText.text = "One eye test instructions."
    }
    @IBAction func skipButtonPressed(_ sender: Any) {
        instructionText.text = "Skip button."
        
    }
}
