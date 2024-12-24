import UIKit
var finalAcuityScore = -Double.infinity
class TumblingEViewController: UIViewController {
    let acuityList = [200, 160, 125, 100, 80, 63, 50, 40, 32, 20, 16]
    var currentAcuityIndex = 0
    var trial = 1 // Number of letters presented in the current acuity level
    var correctAnswersInSet = 0 // Number of correct answers in current set of 10 letters
    var correctAnswersAcrossAcuityLevels: [Int: Int] = [:]
    var counter = 0
    var SKIP = 5
    var MAX_CORRECT = 10
    
    let usFootToLogMAR: [Int: Double] = [
        10: -0.3,
        12: -0.2,
        16: -0.1,
        20: 0.0,
        25: 0.1,
        32: 0.2,
        40: 0.3,
        50: 0.4,
        63: 0.5,
        80: 0.6,
        100: 0.7,
        125: 0.8,
        160: 0.9,
        200: 1.0,
        250: 1.1,
        320: 1.2,
        400: 1.3,
        500: 1.4,
        630: 1.5,
        800: 1.6,
        1000: 1.7,
        1260: 1.8,
        1600: 1.9,
        2000: 2.0
    ]
    
    // var consecutiveCorrect = 0
    
    // MARK: - UI Elements
    private lazy var letterLabel: UILabel = {
        let label = UILabel()
        label.text = "E"
        label.font = UIFont(name: "OpticianSans-Regular", size: 100)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var scoreLabel: UILabel = {
        let label = UILabel()
        label.text = "(Debugging) Score: 0/0"
        label.font = UIFont.systemFont(ofSize: 24)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var instructionLabel: UILabel = {
        let label = UILabel()
        label.text = "Please swipe in the direction the E is pointing."
        label.font = UIFont.systemFont(ofSize: 27, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        return label
    }()
    
    // MARK: - Properties
    private var currentRotation: Double = 0
    private var score = 0
    private var totalAttempts = 0
    private let possibleRotations = [0.0, 90.0, 180.0, 270.0] // right, down, left, up
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        print("TumblingEViewController - viewDidLoad")
        view.backgroundColor = .white
        setupUI()
        if let selectedAcuity = selectedAcuity {
            currentAcuityIndex = getIndex(numList: acuityList, value: selectedAcuity)
            print("The index of \(selectedAcuity) is \(currentAcuityIndex).")
            
        } else {
            print("Selected acuity is nil.")
        }
        // Set the size of the letter for the current acuity
        set_Size_E(letterLabel, desired_acuity: acuityList[currentAcuityIndex], letterText: "E")
        view.layoutIfNeeded()
        setupGestureRecognizers()
        generateNewE()
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        print("TumblingEViewController - setupUI started")
        // Add subviews
        view.addSubview(letterLabel)
        view.addSubview(scoreLabel)
        view.addSubview(instructionLabel)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            letterLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            letterLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            scoreLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            scoreLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scoreLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            instructionLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -50),
            instructionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            instructionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
        print("TumblingEViewController - constraints activated")
    }
    
    private func setupGestureRecognizers() {
        let directions: [UISwipeGestureRecognizer.Direction] = [.right, .left, .up, .down]
        
        for direction in directions {
            let swipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
            swipe.direction = direction
            view.addGestureRecognizer(swipe)
        }
    }
    
    // MARK: - Gesture Handling
    @objc private func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        var isCorrect = 0
        
        switch (gesture.direction, currentRotation) {
        case (.right, 0), (.down, 90), (.left, 180), (.up, 270):
            isCorrect = 1
            score += 1
            correctAnswersInSet += 1 // Track correct answers in the current set of 10
            // consecutiveCorrect += 1
        default:
            isCorrect = 0
            // consecutiveCorrect = 0
        }
        
        totalAttempts += 1
        trial += 1 // Increment the trial count within this set
        updateScore()
        
        // Visual feedback
        letterLabel.textColor = isCorrect == 1 ? .green : .red
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.letterLabel.textColor = .black
            self?.processNextTrial()
        }
    }
    
    private func processNextTrial() {
        print("trial:", trial, "correctAnswersInSet:",correctAnswersInSet)
        let acuity = acuityList[currentAcuityIndex]
        correctAnswersAcrossAcuityLevels[acuity] = correctAnswersInSet
        print("correctAnswersAcrossAcuityLevels:", correctAnswersAcrossAcuityLevels)
        print(currentAcuityIndex, acuity)
        // Check if trial count has reached 10 or if the user has first 5 correct
        if (trial > 10) || ((trial == SKIP + 1) && (correctAnswersInSet == SKIP)) {
            if (trial == SKIP + 1) && (correctAnswersInSet == SKIP){
                print("skip")
                correctAnswersAcrossAcuityLevels[acuity] = MAX_CORRECT
                correctAnswersInSet = MAX_CORRECT
            }
            if currentAcuityIndex == acuityList.count - 1 { // Successfully completed the smallest size
                endTest(withAcuity: acuity, amtCorrect: correctAnswersInSet)
                return
            }
            if correctAnswersInSet < 6 { // If the user cannot get at least 6 letters correct
                if currentAcuityIndex <= 0 { // At largest letter size
                    print("You are BLIND! We cannot assess you.")
                    endTest(withAcuity: acuity, amtCorrect: correctAnswersInSet)
                } else { // Move back to previous acuity if incorrect
                    let previousAcuity = acuityList[currentAcuityIndex - 1]
                    if correctAnswersAcrossAcuityLevels[previousAcuity] != nil {
                        print("HI")
                        endTest(withAcuity: acuity, amtCorrect: correctAnswersInSet)
                    } else {
                        print("Going back to larger acuity...")
                        currentAcuityIndex -= 1
                        set_Size_E(letterLabel, desired_acuity: acuityList[currentAcuityIndex], letterText: "E") // Update the letter size
                    }
                }
            } else { // User gets at least 6 letters correct, advance to next level
                let nextAcuity = acuityList[currentAcuityIndex + 1]
                if correctAnswersAcrossAcuityLevels[nextAcuity] != nil {
                    endTest(withAcuity: nextAcuity, amtCorrect: correctAnswersAcrossAcuityLevels[nextAcuity]!)
                } else {
                    print("Advancing to smaller acuity...")
                    currentAcuityIndex += 1
                    set_Size_E(letterLabel, desired_acuity: acuityList[currentAcuityIndex], letterText: "E") // Update the letter size
                }
            }
            // Reset trial counter and correct answers count
            trial = 1
            correctAnswersInSet = 0
        }
        generateNewE() // Generate the next letter with updated size or same size
    }
    
    private func updateScore() {
        scoreLabel.text = "Score: \(score)/\(totalAttempts)"
    }
    
    private func generateNewE() {
        currentRotation = possibleRotations.randomElement() ?? 0
        UIView.animate(withDuration: 0.1) {
            self.letterLabel.transform = CGAffineTransform(rotationAngle: CGFloat(self.currentRotation) * .pi / 180)
        }
    }
    
    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowResults",
           let resultVC = segue.destination as? ResultViewController {
            resultVC.score = score
            resultVC.totalAttempts = totalAttempts
        }
    }
    
    // MARK: - Public Methods
    // Function to set the size of the "E" based on visual acuity
    func set_Size_E(_ oneLetter: UILabel?, desired_acuity: Int, letterText: String?) -> String? {
        let visual_angle = tan(((Double(desired_acuity) / 20) * 5.0) / 60 * Double.pi / 180)
        let scaling_correction_factor = 1 / 2.54  // Conversion to cm
        let scale_factor = 2 * Double(averageDistanceCM) * visual_angle * scaling_correction_factor
        
        if let nonNilLetterText = letterText, let oneLetter = oneLetter {
            oneLetter.text = nonNilLetterText
            
            // Adjust size based on scale factor
            oneLetter.frame.size = CGSize(width: (scale_factor * 6 * ppi), height: (scale_factor * ppi))
            
            // Set the font size proportional to the label size
            oneLetter.font = oneLetter.font.withSize(2 / 3 * oneLetter.frame.height)
            
            return nonNilLetterText
        }
        
        return nil
    }
    
    func getIndex(numList: [Int], value: Int) -> Int {
        for (index, val) in numList.enumerated() {
            if val == value {
                return index
            }
        }
        return -1
    }
    
    func endTest(withAcuity finishAcuity: Int, amtCorrect: Int, totalLetters: Int = 10) {
        let amtWrongCurrent = (10.0-Double(amtCorrect))
        //let amtWrongNext = 10.0 - Double(correctAnswersAcrossAcuityLevels[acuityList[currentAcuityIndex-1]]!)
        print("You have an acuity of", finishAcuity, "with", amtWrongCurrent, "letters wrong on that line.")
        //print("In the next acuity, you have an acuity of", acuityList[currentAcuityIndex+1], "with", amtWrongNext, "letters wrong on that line.")
        finalAcuityScore = usFootToLogMAR[finishAcuity]!
        finalAcuityScore += amtWrongCurrent / 100.0
        // Pass this score to the results page via the prepare method
        print("Test completed with final acuity level: \(finalAcuityScore)")
        
        // Navigate to the results screen
        performSegue(withIdentifier: "ShowResults", sender: self)
    }
}
