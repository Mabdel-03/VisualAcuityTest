//
//  OneEyeInstruc.swift
//  Distance Measure Test
//
//  Created by Maggie Bao on 6/4/25.
//

import Foundation
import UIKit
import AVFoundation

class OneEyeInstruc: UIViewController {
    @IBOutlet weak var instructionText: UILabel!
    @IBOutlet weak var oneEyeInstructions: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateText()
        setupCenteredUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateText()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        playAudioInstructions()
    }
    
    private func setupCenteredUI() {
        // Center the instruction text
        instructionText.textAlignment = .center
        instructionText.numberOfLines = 0
        
        // Center the text field
        oneEyeInstructions.textAlignment = .center
    }
    
    private func playAudioInstructions() {
        let instructionText: String
        if eyeNumber == 2 {
            instructionText = "Prepare for your right eye vision test. Cover your left eye and look at the screen with your right eye. When ready, tap 'Begin Test' to start, or tap 'Skip' to skip this eye."
        } else {
            instructionText = "Prepare for your left eye vision test. Cover your right eye and look at the screen with your left eye. When ready, tap 'Begin Test' to start, or tap 'Skip' to skip this eye."
        }
        SharedAudioManager.shared.playText(instructionText, source: "Eye Instructions")
    }
    
    private func updateText() {
        if eyeNumber == 2 {
            oneEyeInstructions.text = "Right Test"
            instructionText.text = "Close your left eye and look at the screen with your right eye. When ready, tap 'Begin Test' to start, or tap 'Skip' to skip this eye."
        } else {
            oneEyeInstructions.text = "Left Test"
            instructionText.text = "Close your right eye and look at the screen with your left eye. When ready, tap 'Begin Test' to start, or tap 'Skip' to skip this eye."
        }
    }
    
    @IBAction func skipButtonPressed(_ sender: Any) {
        if eyeNumber == 2 {
            // Right eye test (tested first) - skip to left eye test
            finalAcuityDictionary[2] = "LogMAR: -1.000, Snellen: 20/-1"
            eyeNumber = 1
            updateText()
        } else {
            // Left eye test (tested second) - go to results
            finalAcuityDictionary[1] = "LogMAR: -1.000, Snellen: 20/-1"
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let resultVC = storyboard.instantiateViewController(withIdentifier: "ResultViewController") as? ResultViewController {
                navigationController?.pushViewController(resultVC, animated: true)
            }
        }
    }
}
