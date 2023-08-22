//
//  Test.swift
//  Distance Measure Test
//
//  Created by Anderson Men on 8/7/23. Edited by Maggie Bao 8/21/23.
//

import UIKit

class Test: UIViewController {
    var scaleFactor: CGFloat = 50;
    var letterText: String = "hi";
    @IBOutlet weak var oneLetter: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        oneLetter.text = letterText;
        oneLetter.font = oneLetter.font.withSize(scaleFactor);
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
