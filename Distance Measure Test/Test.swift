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

func spaceBetweenCharacters(input: String) -> String {
    var spacedString = ""
    for character in input {
        spacedString.append(character)
        spacedString.append("   ")
    }
    // Remove the last space
    if !spacedString.isEmpty {
        spacedString.removeLast(3)
    }
    return spacedString
}

func removeSpaces(from input: String) -> String {
    return input.replacingOccurrences(of: " ", with: "")
}

func randomLetters(size: Int) -> String {
    let validLetters = ["S", "K", "H", "N", "O", "C", "D", "V", "R", "Z"]
    
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
        oneLetter.text = nonNilLetterText //spaceBetweenCharacters(input:nonNilLetterText)
        oneLetter.frame.size = CGSize(width: (scale_factor * 6 * ppi), height: (scale_factor * ppi))
        oneLetter.font = oneLetter.font.withSize(2 / 3 * (oneLetter.frame.height))
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
    ///Test screen
    ///
    let acuityList = [200, 160, 125, 100, 80, 63, 50, 40, 32, 25, 20, 16, 12, 10]
    var currentAcuityIndex = 0
    var trial = 1
    var displayLetters: [Int: String] = [:]
    var userResponses: [Int: String] = [:]
    var acuityVisits: [Int: Int] = [:]
    var counter = 0
    var displayTrial = ""
    
    
    @IBOutlet weak var LetterRow1: UILabel!
    @IBOutlet weak var tempVoiceText: UILabel!
    
    var speechRecognizer = SpeechRecognizer()
    var transcriptString = ""
    var gptTranscript = ""
    var hasTranscript: Bool = false
    var transcriptTrial = ""
    
    
    var randomLetter: String = "E";
    
    override func viewDidLoad() { //upon opening page
        super.viewDidLoad()
        speechRecognizer.startTranscribing(); //enable speech
        if let selectedAcuity = selectedAcuity {
            currentAcuityIndex = getIndex(numList: acuityList, value: selectedAcuity)
            print("The index of \(selectedAcuity) is \(currentAcuityIndex).")
            
        } else {
            print("Selected acuity is nil.")
        }
        initializeLabels()
    }
    
    func initializeLabels() {//set acuity letter text and font
        for acuity in acuityList {
            if let label = self.view.viewWithTag(acuity) as? UILabel {
                var tempLabel: UILabel? = label // Create a modifiable variable
                print(acuity)
                set_ETDRS(&tempLabel, desired_acuity: acuity, letterText: "E")
                acuityVisits[acuity] = 0
            }
        }
        setNextLetter()
    }
    func setNextLetter() {
            counter += 1 // update counter
            transcriptTrial += transcriptString // update transcript for trial
            print("current Acuity Index",currentAcuityIndex)
            let tempLetter = randomLetters(size: 1)
            set_ETDRS(&LetterRow1, desired_acuity: acuityList[currentAcuityIndex], letterText: tempLetter)
            displayTrial += tempLetter
    }

    func processTranscription() {
            guard hasTranscript, currentAcuityIndex < acuityList.count else { return }
            let acuity = acuityList[currentAcuityIndex]
            userResponses[trial] = transcriptTrial
            displayLetters[trial] = displayTrial
            acuityVisits[acuity, default: 0] += 1

        if assessInput(inputSeq: displayLetters[trial]!, outputSeq: userResponses[trial]!) == 1 {//if in the trial user got everything right
                if acuityVisits[acuity]! >= 2 {//if that acuity has already been completed twice
                    print("case 1")
                    endTest(withAcuity: acuity)
                } else {//if not completed twice
                    currentAcuityIndex += 1
                    trial += 1
                    displayTrial = ""
                    transcriptTrial = ""
                    setNextLetter()
                }
            } else {//if get wrong
                trial += 1
                if currentAcuityIndex > 0 {
                    currentAcuityIndex -= 1
                }
                displayTrial = ""
                transcriptTrial = ""
                setNextLetter()
            }
            hasTranscript = false
    }

    func endTest(withAcuity acuity: Int) {
        // Process final results and possibly navigate to a results screen
        print("Test completed with final acuity level: \(acuity)")
        exit(0)
    }
    
    @IBAction func startIsPressed(_ sender: Any) {
        speechRecognizer.startTranscribing();
    }
    
    @IBAction func stopIsPressed(_ sender: Any) {
        speechRecognizer.stopTranscribing()
            let transcriptString = speechRecognizer.transcript
            getCorrectLetter(transcription: transcriptString) { correctedLetter in
                DispatchQueue.main.async {
                    if let correctedLetter = correctedLetter {
                        print("Corrected Letter: \(correctedLetter)")
                        self.tempVoiceText.text = correctedLetter
                        transcriptString = correctedLetter
                    } else {
                        print("Failed to get corrected letter.")
                        self.tempVoiceText.text = "Error"
                    }
                }
            }
            speechRecognizer.resetTranscript()
            hasTranscript = true
        }
    
    @IBAction func nextLineIsPressed(_ sender: Any) {
        //take input
        speechRecognizer.stopTranscribing()
            let transcriptString = speechRecognizer.transcript
            getCorrectLetter(transcription: transcriptString) { correctedLetter in
                DispatchQueue.main.async {
                    if let correctedLetter = correctedLetter {
                        print("Corrected Letter: \(correctedLetter)")
                        self.tempVoiceText.text = correctedLetter
                        transcriptString = correctedLetter
                    } else {
                        print("Failed to get corrected letter.")
                        self.tempVoiceText.text = "Error"
                    }
                }
            }
            speechRecognizer.resetTranscript()
            hasTranscript = true
        
        setNextLetter()
        if counter % 5 == 0 && counter != 0 {
            processTranscription()
        }
        print("Correct letters so far:",displayTrial)
        print("Your letters so far:",transcriptTrial)
        print("Correct Letters across all trials:",displayLetters)
        print("Your responses across all trials:",userResponses)
        print("Number of acuity visits:",acuityVisits)

        //start transcribing again
        speechRecognizer.startTranscribing()
        }
    }
