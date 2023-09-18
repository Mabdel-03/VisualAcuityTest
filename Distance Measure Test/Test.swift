//
//  Test.swift
//  Distance Measure Test
//
//  Created by Anderson Men on 8/7/23. Edited by Maggie Bao 8/21/23, 8/27/23, 9/10/23.
//

import UIKit

func getCurrentDevicePPI() -> CGFloat {
    var systemInfo = utsname()
    uname(&systemInfo)
    let modelCode = withUnsafePointer(to: &systemInfo.machine) {
        $0.withMemoryRebound(to: CChar.self, capacity: 1) {
            ptr in String.init(validatingUTF8: ptr)
        }
    }

    let identifier: String = modelCode ?? "unknown"

    switch identifier {
    // Add all known device models and their PPIs here
    case "iPhone10,1", "iPhone10,4":    // iPhone 8
        return 326
    case "iPhone10,2", "iPhone10,5":    // iPhone 8 Plus
        return 401
    case "iPhone10,3", "iPhone10,6":    // iPhone X
        return 458
    // ... add other device models ...
    default:
        // Fallback to a default PPI or perhaps return nil and handle it
        return 326  // Default PPI for many iPhones like iPhone 6/7/8
    }
}

class Test: UIViewController {
    var scaleFactor: CGFloat = 50;
    var letterText: String = "e";
    var speechRecognizer = SpeechRecognizer();
    @IBOutlet weak var oneLetter: UILabel!
    @IBOutlet weak var tempVoiceText: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        //oneLetter.font = oneLetter.font.withSize(scaleFactor);
        let ppi = getCurrentDevicePPI()
        let pointsFor1Inch = 1 * ppi

        // Assuming you have a UILabel to display the letter
        let oneLetter = UILabel()
        oneLetter.text = letterText;
        oneLetter.textAlignment = .center
        oneLetter.frame.size = CGSize(width: pointsFor1Inch, height: pointsFor1Inch)
        // Set the font size or adjust the label size here if needed

        view.addSubview(oneLetter)
    }
    
    @IBAction func startIsPressed(_ sender: Any) {
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
