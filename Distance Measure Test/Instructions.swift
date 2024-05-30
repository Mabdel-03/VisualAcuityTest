//
//  Instructions.swift
//  Distance Measure Test
//
//  Created by Anderson Men on 8/7/23. Edited by Maggie Bao 8/20/23.
//

import UIKit

class Instructions: UIViewController {
    @IBOutlet weak var instructionText: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        instructionText.text = "Welcome to our app based ETDRS Visual Acuity Test. To perform the test, we must first find the optimal distance for you to take the test at. To do so, in the next screen, you must hold the phone at a distance in which the displayed image of the white flower is clear and easy to see. Once you find a comfortable distance, hold your phone there, press the 'capture distance' button, and then click begin test;"
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
