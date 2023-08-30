//
//  Test.swift
//  Distance Measure Test
//
//  Created by Anderson Men on 8/7/23. Edited by Maggie Bao 8/21/23, 8/27/23.
//

import UIKit

class Test: UIViewController {
    var scaleFactor: CGFloat = 50;
    var letterText: String = "hi";
    var speechRecognizer = SpeechRecognizer();
    @IBOutlet weak var oneLetter: UILabel!
    @IBOutlet weak var tempVoiceText: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        oneLetter.text = letterText;
        oneLetter.font = oneLetter.font.withSize(scaleFactor);
    }
    
    @IBAction func isPressed(_ sender: Any) {
        speechRecognizer.startTranscribing();
    }
    
    @IBAction func stopIsPressed(_ sender: Any) {
        speechRecognizer.stopTranscribing();
        tempVoiceText.text = speechRecognizer.transcript;
        speechRecognizer.resetTranscript();
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
