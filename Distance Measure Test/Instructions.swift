//
//  Instructions.swift
//  Distance Measure Test
//
//  Created by Anderson Men on 8/7/23. Edited by Maggie Bao 8/20/23.
//

import UIKit
import AVFoundation

/* Instructions class is designed to manage the instructions scene on the
    visual acuity app. On this page, the user is given generalinstructions on how to
    perform the test.
*/
class Instructions: UIViewController {
    @IBOutlet weak var instructionText: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        instructionText.text = "Follow the instructions on each screen to complete your vision test."
        
        // Center the instruction text
        instructionText.textAlignment = .center
        instructionText.numberOfLines = 0
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        playAudioInstructions()
    }
    
    /* Plays audio instructions to the user.
    */
    private func playAudioInstructions() {
        let instructionText = "Follow the instructions on each screen to complete your vision test."
        SharedAudioManager.shared.playText(instructionText, source: "Instructions")
    }
}
