import UIKit

class TumblingEViewController: UIViewController {
    
    let acuityList = [200, 160, 125, 100, 80, 63, 50, 40, 32, 20, 10]
    var currentAcuityIndex = 0
    var trial = 1
    var displayLetters: [Int: String] = [:]
    var userResponses: [Int: String] = [:]
    var acuityVisits: [Int: Int] = [:]
    var counter = 0
    var displayTrial = ""
    
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
        label.text = "Score: 0/0"
        label.font = UIFont.systemFont(ofSize: 17)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var instructionLabel: UILabel = {
        let label = UILabel()
        label.text = "Swipe in the direction the E is pointing"
        label.font = UIFont.systemFont(ofSize: 17)
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

        if let selectedAcuity = selectedAcuity {
            currentAcuityIndex = getIndex(numList: acuityList, value: selectedAcuity)
            print("The index of \(selectedAcuity) is \(currentAcuityIndex).")
        } else {
            print("Selected acuity is nil.")
        }

        setupUI()
        // Call set_Size_E to adjust the letter size based on the current acuity
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
            // Letter Label constraints
            letterLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            letterLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            // Score Label constraints
            scoreLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            scoreLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scoreLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Instruction Label constraints
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
        var isCorrect = false
        
        switch (gesture.direction, currentRotation) {
        case (.right, 0), (.down, 90), (.left, 180), (.up, 270):
            isCorrect = true
            score += 1
        default:
            isCorrect = false
        }
        
        totalAttempts += 1
        updateScore()
        
        // Visual feedback
        letterLabel.textColor = isCorrect ? .green : .red
        
        // Reset after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.letterLabel.textColor = .black
            self?.generateNewE()
            
            // Check if test should end
            if self?.totalAttempts == 10 { // Adjust number of attempts as needed
                self?.performSegue(withIdentifier: "ShowResults", sender: self)
            }
        }
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
            
            // Return the set text
            return nonNilLetterText
        }
        
        return nil
    }
}
