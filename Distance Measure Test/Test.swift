//
//  Test.swift
//  Distance Measure Test
//
//  Created by Anderson Men on 8/7/23. Edited by Maggie Bao 8/21/23, 8/27/23, 9/10/23. 9/30/23
//

import UIKit
import DevicePpi

let ppi: Double = {
    switch Ppi.get() {
    case .success(let ppi):
        return ppi
    case .unknown(let bestGuessPpi, _):
        return bestGuessPpi
    }
}()

func randomLetters(size: Int) -> String {
    let validLetters = ["E", "T", "D", "R", "S"]
    
    // Ensure the requested size does not exceed the number of available letters
    guard size <= validLetters.count else {
        return "Size exceeds the number of unique letters available"
    }
    // Shuffle the valid letters
    let shuffledLetters = validLetters.shuffled()
    
    // Take the first 'size' elements and join them into a string
    return String(shuffledLetters.prefix(size).map { String($0) }.joined())
}

func set_ETDRS(_ oneLetter: inout UILabel!, desired_acuity: Int, letterText: String?) -> String? {
    let visual_angle = tan(((Double(desired_acuity / 20) * 5.0) / 60) * Double.pi / 180)
    let scale_factor = 2 * Double(averageDistanceCM) * visual_angle
    if let nonNilLetterText = letterText, oneLetter != nil {
        oneLetter.text = nonNilLetterText
        oneLetter.frame.size = CGSize(width: (scale_factor * 6 * ppi), height: (scale_factor * ppi))
        oneLetter.font = oneLetter.font.withSize(2/3 * (oneLetter.frame.height))
        return nonNilLetterText // Return the text that was set
    }
    return nil // Return nil if there was no text set
}


func assessInput(inputSeq: String, outputSeq: String) -> Int {
    guard inputSeq.count == outputSeq.count else { return -1 }
    for (index, inputC) in inputSeq.enumerated() {
        let outputIndex = outputSeq.index(outputSeq.startIndex, offsetBy: index)
        if inputC != outputSeq[outputIndex] {
            return -1
        }
    }
    return 1
}

func getIndex(numList: [Int], value: Int) -> Int {
    for (index, val) in numList.enumerated() {
        if val == value {
            return index
        }
    }
    return -1
}

class Test: UIViewController {
    let averageDistanceCM = 40

    @IBOutlet weak var B200: UILabel!
    @IBOutlet weak var B160: UILabel!
    @IBOutlet weak var B100: UILabel!
    @IBOutlet weak var B125: UILabel!
    @IBOutlet weak var B80: UILabel!
    @IBOutlet weak var B63: UILabel!
    @IBOutlet weak var B50: UILabel!
    @IBOutlet weak var B40: UILabel!
    
    @IBOutlet weak var LetterRow1: UILabel!
    @IBOutlet weak var tempVoiceText: UILabel!
    var transcriptString = ""
    var randomLetter: String = "E";
    var speechRecognizer = SpeechRecognizer();
    override func viewDidLoad() {
        super.viewDidLoad()
        
        set_ETDRS(&B200, desired_acuity: 200, letterText: randomLetter)
        set_ETDRS(&B160, desired_acuity: 160, letterText: randomLetter)
        set_ETDRS(&B100, desired_acuity: 100, letterText: randomLetter)
        set_ETDRS(&B125, desired_acuity: 125, letterText: randomLetter)
        set_ETDRS(&B80, desired_acuity: 80, letterText: randomLetter)
        set_ETDRS(&B63, desired_acuity: 63, letterText: randomLetter)
        set_ETDRS(&B50, desired_acuity: 50, letterText: randomLetter)
        set_ETDRS(&B40, desired_acuity: 40, letterText: randomLetter)
        
        
        var startAcuity = 100 // Example value; ensure this is defined based on your application's needs
        set_ETDRS(&LetterRow1, desired_acuity: startAcuity, letterText: randomLetters(size: 5))
    
        var testCond = true
        var trial = 1
        let acuityList = [200, 160, 125,
                          100, 80, 63, 50, 40, 32,
                          25, 20, 16, 12, 10]
        var index = getIndex(numList: acuityList, value: startAcuity)
        var finalVal: Int
        var displayLetters = [Int: String]()
        var acuityVisits: [Int: Int] = [200: 0, 160: 0, 125: 0,
                                           100: 0, 80: 0, 63: 0,
                                           50: 0, 40: 0, 32: 0,
                                           25: 0, 20: 0, 16: 0,
                                           12: 0, 10: 0]

        var userLetters = [Int: String]()
        while testCond {
            let acuity = acuityList[index]
            //set_ETDRS(&LetterRow1, desired_acuity: acuity, letterText: randomLetters(size: 5))
            print(type(of: LetterRow1.text))
            displayLetters[trial] = LetterRow1.text
            userLetters[trial] = transcriptString

            acuityVisits[acuity, default: 0] += 1

            if acuityVisits[acuity]! > 2 {
                finalVal = acuity
                testCond = false
            }
            else {
                index += assessInput(inputSeq: displayLetters[trial]!, outputSeq: userLetters[trial]!)
                trial += 1
            }
        }
    }
    
    @IBAction func startIsPressed(_ sender: Any) {
        speechRecognizer.startTranscribing();
    }
    
    @IBAction func stopIsPressed(_ sender: Any) {
        speechRecognizer.stopTranscribing();
        let transcriptString = speechRecognizer.transcript;
        tempVoiceText.text = transcriptString
        speechRecognizer.resetTranscript();
        
    }
    
    @IBAction func nextLineIsPressed(_ sender: Any) {
        
    }
}
