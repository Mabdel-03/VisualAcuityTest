//
//  OneEyeInstruc.swift
//  Distance Measure Test
//
//  Created by Maggie Bao on 6/4/25.
//

import Foundation
import UIKit
import AVFoundation

/* OneEyeInstruc class is designed to display the instructions scene for just one eye.
    On this page, the user is given instructions on how to perform the test for either the
    left or right eye.
*/
class OneEyeInstruc: UIViewController {
    @IBOutlet weak var instructionText: UILabel!
    @IBOutlet weak var oneEyeInstructions: UITextField!
    @IBOutlet weak var testTypeLabel: UILabel!
    
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
    
    /* Sets up the UI for the one eye instructions scene.
    */
    private func setupCenteredUI() {
        // Center the instruction text and set standard font
        instructionText.textAlignment = .center
        instructionText.numberOfLines = 0
        instructionText.drawInstruction()
        
        // Center the text field and set color
        oneEyeInstructions.textAlignment = .center
        oneEyeInstructions.drawHeader()
        
        // Center the test type label and apply header2 style
        testTypeLabel?.textAlignment = .center
        testTypeLabel?.drawHeader2()
        
        // Add decorative daisies
        addDecorativeDaisies()
    }
    
    /* Adds decorative daisy flowers to the background for visual cohesion.
    */
    private func addDecorativeDaisies() {
        // Decorative daisy 1 - top left (teal)
        addDecorativeDaisy(
            size: 100,
            petalColor: UIColor(red: 0.224, green: 0.424, blue: 0.427, alpha: 1.0),
            centerColor: UIColor(red: 0.251, green: 0.427, blue: 0.455, alpha: 1.0),
            alpha: 0.12,
            leadingOffset: 20,
            topOffset: 80
        )
        
        // Decorative daisy 2 - bottom right (magenta)
        addDecorativeDaisy(
            size: 95,
            petalColor: UIColor(red: 0.788, green: 0.169, blue: 0.369, alpha: 1.0),
            centerColor: UIColor(red: 0.8, green: 0.2, blue: 0.4, alpha: 1.0),
            alpha: 0.09,
            trailingOffset: 25,
            bottomOffset: 130
        )
    }
    
    /* Plays audio instructions to the user.
    */
    private func playAudioInstructions() {
        let eyeName = eyeNumber == 2 ? "right" : "left"
        let coverEye = eyeNumber == 2 ? "left" : "right"
        
        let instructionText = "Cover your \(coverEye) eye, test with \(eyeName) eye."
        
        SharedAudioManager.shared.playText(instructionText, source: "Eye Instructions")
    }
    
    /* Updates the text on the one eye instructions scene.
    */
    private func updateText() {
        let testType = "Landolt C Test"  // Fixed to Landolt C in this version
        
        if eyeNumber == 2 {
            oneEyeInstructions.text = "Right Eye"
            instructionText.text = "Cover left eye. Tap \"Begin\" when ready to start the test."
        } else {
            oneEyeInstructions.text = "Left Eye"
            instructionText.text = "Cover right eye. Tap \"Begin\" when ready to start the test."
        }
        
        testTypeLabel?.text = testType
    }
    
    /* Begins the Landolt C test (fixed test type in this version).
    */
    @IBAction func beginTestButtonPressed(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        
        // Always navigate to Landolt C test in this version
        if let tumblingVC = storyboard.instantiateViewController(withIdentifier: "TumblingEViewController") as? TumblingEViewController {
            navigationController?.pushViewController(tumblingVC, animated: true)
            print("🔄 Starting Landolt C test for eye \(eyeNumber)")
        } else {
            print("🔄 ❌ Failed to instantiate TumblingEViewController from storyboard")
        }
    }
    
    /* Skips the one eye test and goes to the results scene.
    */
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
