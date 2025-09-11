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
        // Center the instruction text
        instructionText.textAlignment = .center
        instructionText.numberOfLines = 0
        
        // Center the text field and set color
        oneEyeInstructions.textAlignment = .center
        oneEyeInstructions.textColor = UIColor(red: 0.820, green: 0.106, blue: 0.376, alpha: 1.0) // #D11B60
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
        let testType = isETDRSTest ? "ETDRS" : "Landolt C"
        
        if eyeNumber == 2 {
            oneEyeInstructions.text = "Right Eye (\(testType))"
            instructionText.text = "Cover left eye. Tap Begin Test when ready."
        } else {
            oneEyeInstructions.text = "Left Eye (\(testType))"
            instructionText.text = "Cover right eye. Tap Begin Test when ready."
        }
    }
    
    /* Begins the appropriate test based on the selected test type.
    */
    @IBAction func beginTestButtonPressed(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        
        if isETDRSTest {
            // Navigate to ETDRS test
            if let etdrsVC = storyboard.instantiateViewController(withIdentifier: "ETDRSViewController") as? ETDRSViewController {
                navigationController?.pushViewController(etdrsVC, animated: true)
                print("🔤 Starting ETDRS test for eye \(eyeNumber)")
            }
        } else {
            // Navigate to Landolt C test
            if let tumblingVC = storyboard.instantiateViewController(withIdentifier: "TumblingEViewController") as? TumblingEViewController {
                navigationController?.pushViewController(tumblingVC, animated: true)
                print("🔄 Starting Landolt C test for eye \(eyeNumber)")
            }
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
