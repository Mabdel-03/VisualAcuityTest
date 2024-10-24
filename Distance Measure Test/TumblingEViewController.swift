// TumblingEViewController.swift
import UIKit

class TumblingEViewController: UIViewController {
    // MARK: - UI Elements
    private lazy var letterLabel: UILabel = {
        let label = UILabel()
        label.text = "E"
        label.font = UIFont(name: "OpticiansansRegular-0pnR", size: 100) ?? UIFont.systemFont(ofSize: 100, weight: .bold)
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
        view.backgroundColor = .blue // Test color
        setupUI()
        setupGestureRecognizers()
        generateNewE()
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        print("TumblingEViewController - setupUI started")
        // Set background color
        view.backgroundColor = .white
        
        // Add subviews
        view.addSubview(letterLabel)
        view.addSubview(scoreLabel)
        view.addSubview(instructionLabel)
        
        print("TumblingEViewController - subviews added")
        
        // Setup constraints
        NSLayoutConstraint.activate([
            // Letter Label constraints
            letterLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            letterLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            letterLabel.widthAnchor.constraint(equalToConstant: 200),
            letterLabel.heightAnchor.constraint(equalToConstant: 200),
            
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
        UIView.animate(withDuration: 0.3) {
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
    func updateLetterSize(for acuity: Double) {
        let baseSize: CGFloat = 100
        let scaleFactor = CGFloat(acuity)
        letterLabel.font = UIFont(name: "OpticiansansRegular-0pnR", size: baseSize * scaleFactor)
    }
}
