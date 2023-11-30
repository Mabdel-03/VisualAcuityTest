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
func set_ETDRS(_ oneLetter: inout UILabel!, desired_acuity: Int, letterText: String){
    let visual_angle = tan(((Double(desired_acuity/20)*5.0)/60) * Double.pi/180)
    let scale_factor = 2 * Double(averageDistanceCM) * visual_angle
    oneLetter.text = letterText;
    oneLetter.frame.size = CGSize(width: (scale_factor * ppi), height: (scale_factor * ppi))
    oneLetter.font = oneLetter.font.withSize(2/3*(oneLetter.frame.height))
    print(scale_factor * ppi)
/*
    //center letter
    oneLetter.translatesAutoresizingMaskIntoConstraints = false
    oneLetter.lineBreakMode = .byWordWrapping
    oneLetter.textAlignment = .center
    self.view.addSubview(oneLetter)
    oneLetter.widthAnchor.constraint(equalTo: view.widthAnchor).isActive = true
    oneLetter.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
    oneLetter.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
*/
}

class Test: UIViewController {
    @IBOutlet weak var B200: UILabel!
    @IBOutlet weak var B160: UILabel!
    @IBOutlet weak var B100: UILabel!
    @IBOutlet weak var B125: UILabel!
    @IBOutlet weak var B80: UILabel!
    @IBOutlet weak var B63: UILabel!
    @IBOutlet weak var B50: UILabel!
    @IBOutlet weak var B40: UILabel!
    var randomLetter: String = "E";
    //var speechRecognizer = SpeechRecognizer();
    //@IBOutlet weak var oneLetter: UILabel!
    //@IBOutlet weak var tempVoiceText: UILabel!
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
    }
}
/*
    @IBAction func startIsPressed(_ sender: Any) {
        speechRecognizer.startTranscribing();
    }

    @IBAction func stopIsPressed(_ sender: Any) {
        speechRecognizer.stopTranscribing();
        let transcriptString = speechRecognizer.transcript;
        if (transcriptString == "He"){
            tempVoiceText.text = "Correct";
        }
        else{
            tempVoiceText.text = "You are wrong";
        }
        speechRecognizer.resetTranscript();
    }

}*/
