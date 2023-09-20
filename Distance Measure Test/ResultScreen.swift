//
//  ResultScreen.swift
//  Distance Measure Test
//
//  Created by Anderson Men on 9/19/23.
//

import UIKit

class ResultScreen: UIViewController {

    @IBOutlet weak var EnterResult: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        EnterResult.text = "20/200"
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
