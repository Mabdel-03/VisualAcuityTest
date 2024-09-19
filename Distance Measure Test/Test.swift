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
    let scaling_correction_factor = 1 / 2.54  //Conversion to cm
    let scale_factor = 2 * Double(averageDistanceCM) * visual_angle * scaling_correction_factor
    if let nonNilLetterText = letterText, oneLetter != nil {
        oneLetter.text = nonNilLetterText //spaceBetweenCharacters(input:nonNilLetterText)
        oneLetter.frame.size = CGSize(width: (scale_factor * 6 * ppi), height: (scale_factor * ppi))
        oneLetter.font = oneLetter.font.withSize(2 / 3 * (oneLetter.frame.height))
        return nonNilLetterText // Return the text that was set
    }
    return nil // Return nil if there was no text set
}


func assessInput(inputSeq: String, outputSeq: String) -> Int {
    // Step 1: Ensure that the strings are the same length, otherwise return 0 matches
    guard inputSeq.count == outputSeq.count else { return 0 }

    var matchingCount = 0 // Initialize a counter to track matching characters
    
    // Step 2: Iterate through each character in inputSeq
    for (index, inputC) in inputSeq.enumerated() {
        // Step 3: Get the character at the corresponding index in outputSeq
        let outputIndex = outputSeq.index(outputSeq.startIndex, offsetBy: index)
        
        // Step 4: If the characters match, increment the matching count
        if inputC == outputSeq[outputIndex] {
            matchingCount += 1
        }
}
    
    // Step 5: Return the total number of matching characters
    return matchingCount
}


func getIndex(numList: [Int], value: Int) -> Int {
    for (index, val) in numList.enumerated() {
        if val == value {
            return index
        }
    }
    return -1
}
var gptTranscript = ""
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
    @IBOutlet weak var UserInput: UITextField!
    
    var speechRecognizer = SpeechRecognizer()
    var transcriptString = ""
    var hasTranscript: Bool = false
    var transcriptTrial = ""
    
    
    var randomLetter: String = "E";
    
    override func viewDidLoad() { //upon opening page
        super.viewDidLoad()

//        speechRecognizer.startTranscribing(); //enable speech
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
        let tempLetter = randomLetters(size: 1)
        set_ETDRS(&LetterRow1, desired_acuity: acuityList[currentAcuityIndex], letterText: tempLetter)
    }

    func processTranscription() {
        guard currentAcuityIndex < acuityList.count else { return }
        let acuity = acuityList[currentAcuityIndex]
        print("Current Acuity:",acuity)
        // Store responses and display letters
        userResponses[trial] = transcriptTrial
        displayLetters[trial] = displayTrial
        acuityVisits[acuity, default: 0] += 1
        
        // Assess input correctness
        let numCharCorrect = assessInput(inputSeq: displayLetters[trial]!, outputSeq: userResponses[trial]!)
        if numCharCorrect >= 3 { //if the user gets 3 or more letters correct
            if acuityVisits[acuity]! >= 2 { //if user already visited that acuity twice
                endTest(withAcuity: acuity, amtCorrect: numCharCorrect)
            }
            else { //if they have not, can progress to next size
                if currentAcuityIndex < 13 {
                    currentAcuityIndex += 1
                }
                else{
                    endTest(withAcuity: acuity, amtCorrect: numCharCorrect)
                }
            }
        } else { //if user cannot get at least 3 letters
            if currentAcuityIndex <= 0 { //if you are at largest letter size
                endTest(withAcuity: acuity, amtCorrect: numCharCorrect)
            }
            else{ //if still can progress
                currentAcuityIndex -= 1 //go larger size
            }
        }
        trial += 1
        resetForNextTrial()
    }
    
    func resetForNextTrial() {
            // Reset display and transcript trials for the next batch of entries
            displayTrial = ""
            transcriptTrial = ""
            setNextLetter()
        }

    func endTest(withAcuity finishAcuity: Int, amtCorrect: Int, totalLetters: Int = 5) {
        print("In your final trial, you landed on an acuity of", finishAcuity, "and got", amtCorrect, "letters correct out of 5.")
        // Ensure amtCorrect is within a valid range
        guard amtCorrect >= 0 && amtCorrect <= totalLetters else {
            print("Invalid number of correct letters")
            return
        }
        // Calculate the final acuity score using the computeFinalAcuity function
        let finalAcuityScore = computeFinalAcuity(correctLetters: amtCorrect, totalLetters: totalLetters, acuity: finishAcuity)
        // Print the final acuity score
        print("Test completed with final acuity level: \(finalAcuityScore)")
        // Exit or navigate to the results screen
        let myAcuity = "20/" + String(Int(finalAcuityScore.rounded()))
        print(myAcuity)
//        let storyboard = UIStoryboard(name: "Test", bundle: nil) // Replace "Main" with your storyboard name if different
//            if let ResultScreen = storyboard.instantiateViewController(withIdentifier: "ResultScreen") as? ResultScreen {
//                ResultScreen.finalAcuity = finalAcuityScore // Pass data if needed
//                self.present(ResultScreen, animated: true, completion: nil)
//            }
    }

    // Existing computeFinalAcuity function
    func computeFinalAcuity(correctLetters: Int, totalLetters: Int, acuity: Int) -> Double {
        // Ensure the number of correct letters is between 0 and total letters
        guard correctLetters >= 0 && correctLetters <= totalLetters else { return Double(acuity) }
        // Calculate the percentage of correct letters
        let correctPercentage = Double(totalLetters) / Double(correctLetters)
        
        // Calculate the final acuity score
        let finalAcuity = Double(acuity) * correctPercentage
        
        // Return the final acuity score
        return finalAcuity
    }

    
    @IBAction func startIsPressed(_ sender: Any) {
//        speechRecognizer.startTranscribing();
    }
    
    @IBAction func stopIsPressed(_ sender: Any) {
//        speechRecognizer.stopTranscribing()
//        let transcriptString = speechRecognizer.transcript
//        print("HELSKFNLAF", transcriptString)
//            getCorrectLetter(transcription: transcriptString) { correctedLetter in
//                DispatchQueue.main.async {
//                    if let correctedLetter = correctedLetter {
//                        print("Corrected Letter: \(correctedLetter)")
//                        self.tempVoiceText.text = correctedLetter
//                        gptTranscript = correctedLetter
//
//                    } else {
//                        print("Failed to get corrected letter.")
//                        self.tempVoiceText.text = "Error"
//                    }
//                }
//            }
//            speechRecognizer.resetTranscript()
//            hasTranscript = true
        }
    
    @IBAction func nextLineIsPressed(_ sender: Any) {
        counter += 1
        //take input
        //debugging
        if let uinput = UserInput.text {
                    // Optionally display the captured input in a label or do something with it
                    gptTranscript = uinput.uppercased()
                    // Perform any additional actions with the captured input here
        }
        transcriptTrial += gptTranscript // Accumulate transcript for trial
        displayTrial += LetterRow1.text ?? ""
//        speechRecognizer.stopTranscribing()
//        transcriptString = speechRecognizer.transcript
//        print("KJFNKJWF",transcriptString)
//        getCorrectLetter(transcription: transcriptString) { correctedLetter in
//            if let correctedLetter = correctedLetter {
//                print("Corrected Letter: \(correctedLetter)")
//                self.tempVoiceText.text = correctedLetter
//                gptTranscript = correctedLetter
//            } else {
//                print("Failed to get corrected letter.")
//                self.tempVoiceText.text = "Error"
//            }
//        }
//        speechRecognizer.resetTranscript()
//        hasTranscript = true
        setNextLetter()
        print("Correct letters so far:",displayTrial)
        print("Your letters so far:",transcriptTrial)
        if counter % 5 == 0 {
            processTranscription()
            counter = 0
        }
        print("Correct Letters across all trials:",displayLetters)
        print("Your responses across all trials:",userResponses)
        print("Number of acuity visits:",acuityVisits)
        UserInput.text = ""
        //start transcribing again
//        speechRecognizer.startTranscribing()
        }
    }
