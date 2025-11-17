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
    @IBOutlet weak var instructionsHeaderLabel: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        instructionText.text = "Follow the instructions on each screen to complete your vision test."
        
        // Center the instruction text and set standard font
        instructionText.textAlignment = .center
        instructionText.numberOfLines = 0
        instructionText.drawInstruction()
        
        // Apply header style to Instructions label
        instructionsHeaderLabel?.drawHeader()
        
        // Add decorative daisies
        addDecorativeDaisies()
    }
    
    /* Adds decorative daisy flowers to the background for visual cohesion.
    */
    private func addDecorativeDaisies() {
        // Decorative daisy 1 - top right (magenta)
        addDecorativeDaisy(
            size: 110,
            petalColor: UIColor(red: 0.788, green: 0.169, blue: 0.369, alpha: 1.0),
            centerColor: UIColor(red: 0.8, green: 0.2, blue: 0.4, alpha: 1.0),
            alpha: 0.08,
            trailingOffset: 20,
            topOffset: 100
        )
        
        // Decorative daisy 2 - bottom left (teal)
        addDecorativeDaisy(
            size: 100,
            petalColor: UIColor(red: 0.224, green: 0.424, blue: 0.427, alpha: 1.0),
            centerColor: UIColor(red: 0.251, green: 0.427, blue: 0.455, alpha: 1.0),
            alpha: 0.1,
            leadingOffset: 15,
            bottomOffset: 120
        )
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
