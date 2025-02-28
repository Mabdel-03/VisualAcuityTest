import UIKit
var finalAcuityDictionary: [Int: String] = [:] // Dictionary to store final acuity values
var trialNumber: Int = 1
class ResultViewController: UIViewController {
    // MARK: - Properties
    var score: Int = 0
    var totalAttempts: Int = 0
    var logMARValue: Double = 0
    var snellenValue: Double = 0
    // MARK: - UI Elements
    private lazy var scoreLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 24, weight: .medium)
        label.textAlignment = .center
        label.textColor = UIColor.black
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var acuityLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 27, weight: .bold)
        label.textAlignment = .center
        label.textColor = UIColor.black
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
//    private lazy var recommendationLabel: UILabel = {
//        let label = UILabel()
//        label.font = UIFont.systemFont(ofSize: 24)
//        label.textAlignment = .center
//        label.textColor = UIColor.black
//        label.numberOfLines = 0
//        label.backgroundColor = UIColor.systemGray6
//        label.clipsToBounds = true
//        label.translatesAutoresizingMaskIntoConstraints = false
//        return label
//    }()
    
//    private lazy var doneButton: UIButton = {
//        let button = UIButton(type: .system)
//        button.setTitle("Done", for: .normal)
//        button.setTitleColor(.white, for: .normal)
//        button.backgroundColor = UIColor.systemBlue
//        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
//        button.layer.cornerRadius = 10
//        button.addTarget(self, action: #selector(doneButtonTapped), for: .touchUpInside)
//        button.translatesAutoresizingMaskIntoConstraints = false
//        return button
//    }()
    
//    private lazy var retryButton: UIButton = {
//        let button = UIButton(type: .system)
//        button.setTitle("Try Again", for: .normal)
//        button.setTitleColor(.white, for: .normal)
//        button.backgroundColor = UIColor.systemGreen
//        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
//        button.layer.cornerRadius = 10
//        button.addTarget(self, action: #selector(retryTest), for: .touchUpInside)
//        button.translatesAutoresizingMaskIntoConstraints = false
//        return button
//    }()
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        title = "Test Results"
        
        // Add subviews
        view.addSubview(scoreLabel)
        view.addSubview(acuityLabel)
//        view.addSubview(recommendationLabel)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            // Center the acuity label horizontally and move it towards the top of the center
            acuityLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            acuityLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -100), // Moved up slightly
            acuityLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            acuityLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            
            // Center the score label horizontally and place it below the acuity label
            scoreLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scoreLabel.topAnchor.constraint(equalTo: acuityLabel.bottomAnchor, constant: 20),
            scoreLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            scoreLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            
//            // Center horizontally
//               recommendationLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
//               
//               // Place it below the score label
//               recommendationLabel.topAnchor.constraint(equalTo: scoreLabel.bottomAnchor, constant: 20),
//               
//               // Set flexible width constraints with some padding from the edges
//               recommendationLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
//               recommendationLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
//               
//               // Increase the height to allow more text
//               recommendationLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 150)
        ])
        
        // Calculate and display results
//        let percentage = (Double(score) / Double(totalAttempts)) * 100
        
        logMARValue = finalAcuityScore
        snellenValue = 20 * pow(10, logMARValue)
        scoreLabel.text = String(format: "LogMAR Score: %.4f",finalAcuityScore)

        // Display the final acuity score
        acuityLabel.text = String(format: "Snellen Score: 20/%.0f", snellenValue)
        
        
//        // Display the recommendation
//        recommendationLabel.text = getRecommendation(acuity: finalAcuityScore)
    }


    // MARK: - Private Methods

//    private func getRecommendation(acuity: Double) -> String {
//        switch acuity {
//        case 16..<40:
//            return "Your vision appears to be normal. Continue with regular eye check-ups."
//        case 40..<85:
//            return "Minor vision issues may be present. Consider scheduling an eye examination."
//        case 85..<150:
//            return "Moderate vision issues detected. We recommend consulting an eye care professional."
//        default:
//            return "Significant vision issues detected. Please schedule an appointment with an eye care professional as soon as possible."
//        }
//    }
//    
    // MARK: - Actions
    @IBAction func redoTest(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func tapDone(_ sender: Any) {
        // Store the final acuity score in the dictionary
                finalAcuityDictionary[trialNumber] = String(format: "LogMAR: %.4f, Snellen: 20/%.0f", logMARValue, snellenValue)
        print(finalAcuityDictionary)
        // Increment trial number for the next test
        trialNumber += 1
        navigationController?.popToRootViewController(animated: true)
    }
}
