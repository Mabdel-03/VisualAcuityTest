//
//  Test.swift
//  Distance Measure Test
//
//  Created by Anderson Men on 8/7/23. Edited by Maggie Bao 8/21/23, 8/27/23, 9/10/23. 9/30/23
//

import UIKit
import DevicePpi

//BELOW IS GETTING PPI FROM GITHUB PPI PACKAGE https://github.com/Clafou/DevicePpi
let ppi: Double = {
    switch Ppi.get() {
    case .success(let ppi):
        return ppi
    case .unknown(let bestGuessPpi, let error):
        return bestGuessPpi
    }
}()

class Test: UIViewController {
    var scaleFactor: CGFloat = 1;
    var letterText: String = "e";
    var speechRecognizer = SpeechRecognizer();
    @IBOutlet weak var oneLetter: UILabel!
    @IBOutlet weak var tempVoiceText: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        let pointsFor1Inch = ppi
        //print("ppi:",ppi)
        oneLetter.text = letterText;
        oneLetter.frame.size = CGSize(width: pointsFor1Inch, height: pointsFor1Inch)
        oneLetter.font = oneLetter.font.withSize(2/3*(oneLetter.frame.height))
        //center letter
        oneLetter.translatesAutoresizingMaskIntoConstraints = false
        oneLetter.lineBreakMode = .byWordWrapping
        oneLetter.textAlignment = .center
        self.view.addSubview(oneLetter)
        oneLetter.widthAnchor.constraint(equalTo: view.widthAnchor).isActive = true
        oneLetter.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        oneLetter.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
    }
    
    @IBAction func startIsPressed(_ sender: Any) {
        speechRecognizer.startTranscribing();
    }
    
    @IBAction func stopIsPressed(_ sender: Any) {
        speechRecognizer.stopTranscribing();
        let transcriptString = speechRecognizer.transcript;
        if (transcriptString == "He"){
            tempVoiceText.text = "Correct";
            speechRecognizer.resetTranscript();
        }
        else{
            tempVoiceText.text = "You are wrong";
            speechRecognizer.resetTranscript();
        }
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
