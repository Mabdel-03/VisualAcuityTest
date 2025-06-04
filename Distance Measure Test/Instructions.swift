//
//  Instructions.swift
//  Distance Measure Test
//
//  Created by Anderson Men on 8/7/23. Edited by Maggie Bao 8/20/23.
//

import UIKit
import AVFoundation

class Instructions: UIViewController {
    @IBOutlet weak var instructionText: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        instructionText.text = "Welcome to our app based ETDRS Visual Acuity Test. To perform the test, we must first find the optimal distance for you to take the test at. To do so, in the next screen, you must hold the phone at a distance in which the displayed image of the white flower is clear and easy to see. Once you find a comfortable distance, hold your phone there, press the 'capture distance' button, and then click begin test."
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        playAudioInstructions()
    }
    
    private func playAudioInstructions() {
        let instructionText = "Welcome to the ETDRS Visual Acuity Test. First, we need to find the optimal distance for your test. In the next screen, hold your phone at a distance where the white flower image is clear and easy to see. Once you find a comfortable distance, press the 'Capture Distance' button, then tap 'Begin Test'."
        SharedAudioManager.shared.playText(instructionText, source: "Instructions")
    }
}
