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
    @IBOutlet weak var oneEyeInstructions: UITextField!
    override func viewDidLoad() {
        super.viewDidLoad()
        updateText()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateText()
    }
    
    private func updateText() {
        if eyeNumber == 1 {
            oneEyeInstructions.text = "Left Test"
            instructionText.text = "Left test instructions."
        } else {
            oneEyeInstructions.text = "Right Test"
            instructionText.text = "Right test instructions."
        }
    }
    
    @IBAction func skipButtonPressed(_ sender: Any) {
        if eyeNumber == 1 {
            // Left eye test - skip to right eye test
            finalAcuityDictionary[1] = "LogMAR: -1.000, Snellen: 20/-1"
            eyeNumber = 2
            updateText()
        } else {
            // Right eye test - go to results
            // Only set right eye results if they haven't been set yet
            finalAcuityDictionary[2] = "LogMAR: -1.000, Snellen: 20/-1"
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let resultVC = storyboard.instantiateViewController(withIdentifier: "ResultViewController") as? ResultViewController {
                navigationController?.pushViewController(resultVC, animated: true)
            }
        }
    }
}
